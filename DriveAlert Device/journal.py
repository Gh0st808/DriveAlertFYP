"""Persist only run metadata and numeric detections. Never persist video frames."""
import json
import sqlite3
import threading
import time
import uuid

class Journal:
    def __init__(self, path):
        self.lock = threading.RLock()
        self.db = sqlite3.connect(str(path), check_same_thread=False)
        with self.db:
            self.db.execute("CREATE TABLE IF NOT EXISTS runs (id TEXT PRIMARY KEY, started REAL, ended REAL, seen REAL)")
            self.db.execute("CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY, run TEXT, payload TEXT)")
            self.db.execute("CREATE TABLE IF NOT EXISTS event_delivery (id TEXT PRIMARY KEY, sent INTEGER DEFAULT 0, next_attempt REAL DEFAULT 0)")
            self.db.execute("INSERT OR IGNORE INTO event_delivery(id) SELECT id FROM events")
            # On a restart, finish interrupted journeys at the last heartbeat.
            self.db.execute("UPDATE runs SET ended=seen WHERE ended IS NULL")

    def start(self, run_id):
        with self.lock, self.db:
            self.db.execute("INSERT INTO runs VALUES (?, ?, NULL, ?)", (run_id, time.time(), time.time()))

    def heartbeat(self, run_id):
        with self.lock, self.db:
            self.db.execute("UPDATE runs SET seen=? WHERE id=?", (time.time(), run_id))

    def end(self, run_id):
        with self.lock, self.db:
            self.db.execute("UPDATE runs SET ended=?, seen=? WHERE id=? AND ended IS NULL", (time.time(), time.time(), run_id))

    def event(self, run_id, event_type, duration, ear):
        data = {"id": str(uuid.uuid4()), "event_type": event_type, "timestamp": time.time(),
                "duration": duration, "ear_value": ear}
        with self.lock, self.db:
            self.db.execute("INSERT INTO events VALUES (?, ?, ?)", (data["id"], run_id, json.dumps(data)))
            self.db.execute("INSERT INTO event_delivery(id) VALUES (?)", (data["id"],))
        return data

    def get(self, run_id):
        with self.lock:
            row = self.db.execute("SELECT started,ended,seen FROM runs WHERE id=?", (run_id,)).fetchone()
            if row is None:
                return None
            events = [json.loads(x[0]) for x in self.db.execute("SELECT payload FROM events WHERE run=? ORDER BY rowid", (run_id,))]
        return {"run_id": run_id, "started_at": row[0], "ended_at": row[1], "last_seen": row[2], "events": events}


    def pending(self, limit=32):
        with self.lock:
            rows = self.db.execute(
                "SELECT events.id, events.run, events.payload FROM events JOIN event_delivery USING(id) "
                "WHERE event_delivery.sent=0 AND event_delivery.next_attempt<=? ORDER BY events.rowid LIMIT ?",
                (time.time(), limit)).fetchall()
        return [{"id": row[0], "run_id": row[1], "event": json.loads(row[2])} for row in rows]

    def acknowledged(self, event_id):
        with self.lock, self.db:
            self.db.execute("UPDATE event_delivery SET sent=1 WHERE id=?", (event_id,))

    def defer(self, event_id):
        with self.lock, self.db:
            self.db.execute("UPDATE event_delivery SET next_attempt=? WHERE id=?", (time.time()+60, event_id))
