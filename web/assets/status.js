const cards = [...document.querySelectorAll('.card')];
const checked = document.getElementById('checked');

function paint(card, state, text) {
  card.querySelector('.dot').className = 'dot ' + state;
  card.querySelector('.state').textContent = text;
}

function updateButtons(card, up) {
  const busy = card.dataset.busy === '1';
  card.querySelectorAll('button').forEach(btn => {
    const action = btn.dataset.action;
    if (action === 'wake') btn.disabled = busy || up;
    else if (action === 'gui') {
      btn.disabled = busy || !up || !card.dataset.gui;
      btn.textContent = card.dataset.gui === '1' ? 'Close GUI' : 'Open GUI';
    }
    else btn.disabled = busy || !up || (action === 'hibernate' && card.dataset.hibernate === '0');
  });
}

async function check(card) {
  try {
    const res = await fetch('/api/status?host=' + card.dataset.host, { cache: 'no-store' });
    if (!res.ok) throw new Error();
    const { up, gui } = await res.json();
    card.dataset.gui = gui === null || gui === undefined ? '' : gui ? '1' : '0';
    if (card.dataset.busy !== '1') {
      paint(card, up ? 'up' : 'down', up ? 'online' : 'offline');
      updateButtons(card, up);
    }
    return up;
  } catch {
    if (card.dataset.busy !== '1') {
      card.dataset.gui = '';
      paint(card, 'down', 'status unavailable');
      updateButtons(card, false);
    }
    return false;
  }
}

function checkAll() {
  cards.forEach(check);
  checked.textContent = 'checked ' + new Date().toLocaleTimeString();
}

async function runAction(card, action) {
  if (action === 'hibernate' && card.dataset.hibernate === '0') return;
  const isGui = action === 'gui';
  const guiAction = isGui ? (card.dataset.gui === '1' ? 'close' : 'open') : null;
  const verb = action === 'wake' ? 'wake'
    : isGui ? (guiAction === 'open' ? 'open the GUI on' : 'close the GUI on')
    : action;
  const warning = isGui && guiAction === 'close' ? ' This ends its desktop session.' : '';
  if (action !== 'wake' && !confirm(`Really ${verb} ${card.dataset.name}?${warning}`)) return;

  const host = card.dataset.host;
  card.dataset.busy = '1';
  updateButtons(card, true);
  paint(card, 'waking', isGui ? `${guiAction === 'open' ? 'opening' : 'closing'} GUI…`
    : action === 'wake' ? 'sending magic packet…' : `${verb}…`);

  let error = null;
  try {
    const url = action === 'wake'
      ? `/api/wake?host=${host}`
      : isGui ? `/api/gui?host=${host}&action=${guiAction}`
      : `/api/power?host=${host}&action=${action}`;
    const res = await fetch(url, { method: 'POST' });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.detail || body.error || `${verb} failed`);
    }
  } catch (err) {
    error = err.message || `${verb} failed`;
  }

  const wantsUp = action === 'wake';
  const wantsGui = guiAction === 'open';
  const deadline = Date.now() + (isGui && error ? 0
    : wantsUp || (isGui && wantsGui) ? 120000 : 20000);
  let up, done;
  do {
    await new Promise(r => setTimeout(r, wantsUp ? 3000 : 2000));
    up = await check(card);
    done = isGui ? up && (card.dataset.gui === '1') === wantsGui : up === wantsUp;
    if (done) break;
  } while (Date.now() < deadline);

  card.dataset.busy = '0';
  if (done) {
    paint(card, up ? 'up' : 'down', up ? 'online' : 'offline');
  } else if (isGui) {
    paint(card, up ? 'up' : 'down', error || `GUI did not ${guiAction}`);
  } else if (wantsUp) {
    paint(card, 'down', 'wake timed out');
  } else {
    paint(card, 'up', error || 'still online');
  }
  updateButtons(card, up);
}

cards.forEach(card => {
  card.querySelectorAll('button').forEach(btn => {
    btn.addEventListener('click', () => runAction(card, btn.dataset.action));
  });
});

checkAll();
setInterval(() => {
  if (!document.hidden && document.body.dataset.tab === 'status') checkAll();
}, 10000);
