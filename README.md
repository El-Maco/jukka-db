# Jukka

MQTT → SQLite plant moisture logger for `minimaco`, plus the web UI.

## Web UI

Served by Apache on `minimaco` at `http://minimaco/`.

- **Status** tab — the previous maco-status page (wake/power/sleep), unchanged.
- **Jukka** tab — moisture graph (`uPlot`), raw readings or daily averages,
  24 h / 7 d / 30 d / all.

The page is static HTML/CSS/JS in `web/`. It talks to a small read-only
Python API in `web/api/`, which Apache proxies at `/jukka/api` and which reads
`/jukka/jukka.db` directly. New plants appear automatically from the database.

Deploy the UI (no Rust build needed):

```bash
./web/deploy.sh
```

The original status page is backed up on the server as
`/var/www/html/index.html.bak`.

## Daemon

`deploy.sh` builds the i686 Rust binary, runs migrations, rsyncs it to
`minimaco:/jukka` and restarts `jukka.service`.

## Database

- `/jukka/jukka.db` — live SQLite database, written by the daemon.
- `/jukka/jukka-read.db` — 30-minute backup made by `jukka-backup.timer`.

Graph values are normalised to 0–100 % from each plant's
`min_reading`/`max_reading`, using `moist.sql` and `moist-avg.sql`.
