#!/usr/bin/env python3
"""Self-check for the Jukka API range/mode logic. Run: python3 web/api/test_api.py"""
import importlib.util
import os
import sqlite3
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
os.environ["JUKKA_SQL_DIR"] = os.path.dirname(os.path.dirname(HERE))

spec = importlib.util.spec_from_file_location("jukka_api", os.path.join(HERE, "jukka-api.py"))
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)

now = int(time.time())
with tempfile.NamedTemporaryFile(suffix=".db") as f:
    db = sqlite3.connect(f.name)
    db.executescript(
        """
        CREATE TABLE plant (id INTEGER PRIMARY KEY, name TEXT, min_reading INT, max_reading INT);
        CREATE TABLE measurement (id INTEGER PRIMARY KEY, plant_id INT, value INT,
                                  timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP);
        INSERT INTO plant VALUES (1, 'old', 3000, 4095), (2, 'new', 3000, 4095);
        """
    )
    old = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(now - 40 * 86400))
    recent = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(now - 3600))
    db.execute("INSERT INTO measurement (plant_id, value, timestamp) VALUES (1, 4095, ?)", (old,))
    db.execute("INSERT INTO measurement (plant_id, value, timestamp) VALUES (2, 3000, ?)", (recent,))
    db.commit()
    db.close()

    api.DB = f.name
    raw = api.query("raw", now - 86400)
    assert [s["name"] for s in raw["series"]] == ["new"], raw
    assert raw["series"][0]["data"][0][1] == 100.0, raw
    assert raw["updated"] == now - 3600, raw

    everything = api.query("raw", None)
    assert [s["name"] for s in everything["series"]] == ["new", "old"], everything

    daily = api.query("daily", None)
    assert len(daily["series"]) == 2 and len(daily["series"][0]["data"]) == 1, daily

print("api self-check OK")
