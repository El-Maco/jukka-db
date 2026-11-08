#!/usr/bin/env python3
"""Read-only JSON API for the Jukka moisture graph."""
import json
import os
import sqlite3
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.environ.get("JUKKA_DB", "/jukka/jukka.db")
SQL_DIR = os.environ.get("JUKKA_SQL_DIR", HERE)
RANGE_SECONDS = {"24h": 86400, "7d": 7 * 86400, "30d": 30 * 86400, "all": None}


def load_sql(name):
    with open(os.path.join(SQL_DIR, name), encoding="utf-8") as f:
        return f.read().strip().rstrip(";")


RAW_SQL = load_sql("moist.sql")
AVG_SQL = load_sql("moist-avg.sql")


def query(mode, since):
    sql = AVG_SQL if mode == "daily" else RAW_SQL
    sql = f"SELECT * FROM ({sql}) WHERE (? IS NULL OR CAST(time AS INTEGER) >= ?) ORDER BY time"
    conn = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=2)
    try:
        rows = conn.execute(sql, (since, since)).fetchall()
        updated = conn.execute(
            "SELECT MAX(CAST(strftime('%s', timestamp) AS INTEGER)) FROM measurement"
        ).fetchone()[0]
        plants = [row[0] for row in conn.execute("SELECT name FROM plant ORDER BY name")]
    finally:
        conn.close()

    series = {}
    for ts, value, name in rows:
        series.setdefault(name, []).append([int(ts), value])
    return {
        "updated": updated,
        "plants": plants,
        "series": [{"name": name, "data": data} for name, data in sorted(series.items())],
    }


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        if url.path != "/api":
            return self.reply(404, {"error": "not found"})
        params = parse_qs(url.query)
        mode = params.get("mode", ["raw"])[0]
        rng = params.get("range", ["30d"])[0]
        if mode not in ("raw", "daily"):
            return self.reply(400, {"error": "mode must be raw or daily"})
        if rng not in RANGE_SECONDS:
            return self.reply(400, {"error": "range must be 24h, 7d, 30d or all"})
        seconds = RANGE_SECONDS[rng]
        since = None if seconds is None else int(time.time()) - seconds
        try:
            self.reply(200, query(mode, since))
        except sqlite3.Error as e:
            self.reply(500, {"error": f"database: {e}"})

    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8789), Handler).serve_forever()
