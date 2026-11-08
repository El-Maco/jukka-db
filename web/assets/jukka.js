const palette = ['#3ddc84', '#4dabff', '#ffb84d', '#ff6b9d', '#b48cff', '#ff5c5c', '#35d0d0', '#e0d054', '#8bc34a', '#ff9f43'];
function colorFor(name) {
  let h = 0;
  for (const c of name) h = (h * 31 + c.codePointAt(0)) >>> 0;
  return palette[h % palette.length];
}

const chartEl = document.getElementById('chart');
const statusEl = document.getElementById('jukka-status');
let range = '30d';
let mode = 'raw';
let plot = null;
let seriesKey = '';
let loaded = false;

function fmtX(u, splits) {
  const span = u.scales.x.max - u.scales.x.min;
  return splits.map(v => {
    const d = new Date(v * 1000);
    return span < 2 * 86400
      ? d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      : d.toLocaleDateString([], { month: 'short', day: 'numeric' });
  });
}

function opts(names) {
  const width = chartEl.clientWidth || 600;
  return {
    width,
    height: width < 600 ? 300 : 440,
    scales: { x: { time: true }, y: { range: [0, 100] } },
    series: [
      {},
      ...names.map(name => ({
        label: name,
        stroke: colorFor(name),
        width: 2,
        points: { show: false },
        spanGaps: mode === 'daily',
      })),
    ],
    axes: [
      { stroke: '#8b909a', grid: { stroke: '#2a2d34' }, ticks: { stroke: '#2a2d34' }, values: fmtX },
      { scale: 'y', label: 'moisture %', stroke: '#8b909a', grid: { stroke: '#2a2d34' }, ticks: { stroke: '#2a2d34' }, size: 60 },
    ],
    legend: { live: true },
    cursor: { drag: { x: true, y: false } },
  };
}

function toColumns(json) {
  const times = [...new Set(json.series.flatMap(s => s.data.map(([t]) => t)))].sort((a, b) => a - b);
  const index = new Map(times.map((t, i) => [t, i]));
  const cols = json.series.map(s => {
    const y = new Array(times.length).fill(null);
    for (const [t, v] of s.data) y[index.get(t)] = v;
    return y;
  });
  return [times, ...cols];
}

async function load(silent = false) {
  if (!silent) statusEl.textContent = 'loading…';
  try {
    const res = await fetch(`/jukka/api?mode=${mode}&range=${range}`, { cache: 'no-store' });
    if (!res.ok) throw new Error((await res.json().catch(() => ({}))).error || `HTTP ${res.status}`);
    const json = await res.json();
    loaded = true;
    if (!json.series.length) {
      if (plot) { plot.destroy(); plot = null; seriesKey = ''; }
      chartEl.innerHTML = '';
      statusEl.textContent = 'no data in this range — try All';
      return;
    }
    const key = json.series.map(s => s.name).join('\n');
    const data = toColumns(json);
    if (!plot || key !== seriesKey) {
      if (plot) plot.destroy();
      plot = new uPlot(opts(json.series.map(s => s.name)), data, chartEl);
      seriesKey = key;
    } else {
      plot.setData(data, false);
    }
    statusEl.textContent = json.updated
      ? `updated ${new Date(json.updated * 1000).toLocaleString()}`
      : 'no timestamp';
  } catch (err) {
    statusEl.textContent = `error: ${err.message}`;
  }
}

function select(container, attr, value) {
  container.querySelectorAll('button').forEach(b => b.classList.toggle('active', b.dataset[attr] === value));
}

document.getElementById('range').addEventListener('click', e => {
  const btn = e.target.closest('button');
  if (!btn) return;
  range = btn.dataset.range;
  select(e.currentTarget, 'range', range);
  if (plot) { plot.destroy(); plot = null; seriesKey = ''; }
  load();
});

document.getElementById('mode').addEventListener('click', e => {
  const btn = e.target.closest('button');
  if (!btn) return;
  mode = btn.dataset.mode;
  select(e.currentTarget, 'mode', mode);
  if (plot) { plot.destroy(); plot = null; seriesKey = ''; }
  load();
});

window.addEventListener('resize', () => {
  if (plot) plot.setSize({ width: chartEl.clientWidth || 600, height: chartEl.clientWidth < 600 ? 300 : 440 });
});

function activate(tab) {
  document.body.dataset.tab = tab;
  document.querySelectorAll('#tabs button').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
  document.getElementById('tab-status').hidden = tab !== 'status';
  document.getElementById('tab-jukka').hidden = tab !== 'jukka';
  if (tab === 'jukka' && !loaded) load();
}

document.getElementById('tabs').addEventListener('click', e => {
  const btn = e.target.closest('button');
  if (!btn) return;
  activate(btn.dataset.tab);
});

if (location.hash === '#jukka') activate('jukka');

setInterval(() => {
  if (!document.hidden && document.body.dataset.tab === 'jukka') load(true);
}, 60000);
