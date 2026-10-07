import sqlite3
import threading
from pathlib import Path


class Database:
    """SQLite sencilla y segura entre hilos (un bloqueo y una conexión)."""

    def __init__(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(str(path), check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        # WAL: las lecturas no esperan a las escrituras y se hacen menos sincronizaciones a disco.
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.execute("PRAGMA synchronous=NORMAL")
        self._create()

    def _create(self):
        with self._lock:
            self._conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS events (
                    id TEXT PRIMARY KEY,
                    created REAL NOT NULL,
                    kind TEXT NOT NULL,
                    photo INTEGER NOT NULL DEFAULT 0,
                    clip INTEGER NOT NULL DEFAULT 0,
                    notified INTEGER NOT NULL DEFAULT 0
                );
                CREATE INDEX IF NOT EXISTS events_created ON events(created);
                CREATE TABLE IF NOT EXISTS push_subs (
                    endpoint TEXT PRIMARY KEY,
                    p256dh TEXT NOT NULL,
                    auth TEXT NOT NULL,
                    lang TEXT NOT NULL DEFAULT 'es',
                    created REAL NOT NULL
                );
                CREATE TABLE IF NOT EXISTS sessions (
                    token_hash TEXT PRIMARY KEY,
                    expires REAL NOT NULL
                );
                CREATE TABLE IF NOT EXISTS kv (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """
            )
            columns = [row["name"] for row in self._conn.execute("PRAGMA table_info(events)")]
            if "reason" not in columns:       # bases creadas antes de la alarma
                self._conn.execute("ALTER TABLE events ADD COLUMN reason TEXT")
            self._conn.commit()

    def execute(self, sql, params=()):
        with self._lock:
            cur = self._conn.execute(sql, params)
            self._conn.commit()
            return cur.rowcount

    def query(self, sql, params=()):
        with self._lock:
            return [dict(row) for row in self._conn.execute(sql, params).fetchall()]

    def one(self, sql, params=()):
        rows = self.query(sql, params)
        return rows[0] if rows else None

    def kv_get(self, key, default=None):
        row = self.one("SELECT value FROM kv WHERE key = ?", (key,))
        return row["value"] if row else default

    def kv_set(self, key, value):
        self.execute(
            "INSERT INTO kv(key, value) VALUES(?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, value),
        )
