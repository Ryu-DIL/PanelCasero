import hmac
import hashlib
import secrets
import shutil
import time
import uuid
from pathlib import Path

MEDIA = ("photo", "clip")
FILE_NAMES = {"photo": "photo.jpg", "clip": "clip.mp4"}
DEVICE_KINDS = ("alert", "test")          # los que puede crear el iPhone
REASONS = ("motion", "pin")               # por qué saltó una alerta
NOTIFY_KINDS = ("alert", "test")          # los que avisan al subir la foto
MAX_BYTES = {"photo": 3 * 1024 * 1024, "clip": 25 * 1024 * 1024}


def valid_id(value: str) -> bool:
    try:
        return str(uuid.UUID(value)) == value.lower()
    except (ValueError, AttributeError, TypeError):
        return False


def looks_like(name: str, data: bytes) -> bool:
    if name == "photo":
        return data[:2] == b"\xff\xd8"
    return data[4:8] == b"ftyp"


class EventStore:
    """Eventos (alertas) con su foto y su clip de vídeo."""

    def __init__(self, db, root, clock=time.time):
        self.db = db
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self.clock = clock
        secret = db.kv_get("media_secret")
        if not secret:
            secret = secrets.token_hex(32)
            db.kv_set("media_secret", secret)
        self._secret = secret.encode()

    # ---- consulta ----
    @staticmethod
    def _public(row):
        return {
            "id": row["id"],
            "created": row["created"],
            "kind": row["kind"],
            "photo": bool(row["photo"]),
            "clip": bool(row["clip"]),
            "reason": row.get("reason"),
        }

    def get(self, event_id):
        row = self.db.one("SELECT * FROM events WHERE id = ?", (event_id,))
        return self._public(row) if row else None

    def list(self, limit=50, before=None):
        limit = max(1, min(int(limit), 200))
        if before is None:
            rows = self.db.query("SELECT * FROM events ORDER BY created DESC LIMIT ?", (limit,))
        else:
            rows = self.db.query(
                "SELECT * FROM events WHERE created < ? ORDER BY created DESC LIMIT ?",
                (float(before), limit),
            )
        return [self._public(r) for r in rows]

    # ---- escritura ----
    def upsert(self, event_id, kind, created=None, reason=None):
        created = float(created) if created else self.clock()
        # Un evento no puede estar en el futuro.
        created = min(created, self.clock() + 60)
        self.db.execute(
            "INSERT INTO events(id, created, kind, reason) VALUES(?, ?, ?, ?) "
            "ON CONFLICT(id) DO NOTHING",
            (event_id, created, kind, reason),
        )
        return self.get(event_id)

    def path(self, event_id, name) -> Path:
        return self.root / event_id / FILE_NAMES[name]

    def save_media(self, event_id, name, data: bytes):
        folder = self.root / event_id
        folder.mkdir(parents=True, exist_ok=True)
        target = self.path(event_id, name)
        tmp = target.with_suffix(target.suffix + ".part")
        tmp.write_bytes(data)
        tmp.replace(target)
        self.db.execute(f"UPDATE events SET {name} = 1 WHERE id = ?", (event_id,))

    def claim_notification(self, event_id) -> bool:
        """True solo la primera vez (para no avisar dos veces del mismo evento)."""
        return self.db.execute(
            "UPDATE events SET notified = 1 WHERE id = ? AND notified = 0", (event_id,)
        ) > 0

    def delete(self, event_id) -> bool:
        removed = self.db.execute("DELETE FROM events WHERE id = ?", (event_id,)) > 0
        shutil.rmtree(self.root / event_id, ignore_errors=True)
        return removed

    def cleanup(self, days) -> int:
        limit = self.clock() - days * 86400
        old = self.db.query("SELECT id FROM events WHERE created < ?", (limit,))
        for row in old:
            self.delete(row["id"])
        return len(old)

    # ---- enlaces firmados (para la imagen de la notificación) ----
    def _signature(self, event_id, name, exp):
        msg = f"{event_id}|{name}|{exp}".encode()
        return hmac.new(self._secret, msg, hashlib.sha256).hexdigest()[:32]

    def signed_url(self, event_id, name, days=30):
        exp = int(self.clock() + days * 86400)
        return f"/api/events/{event_id}/{name}?exp={exp}&sig={self._signature(event_id, name, exp)}"

    def verify(self, event_id, name, exp, sig) -> bool:
        try:
            exp = int(exp)
        except (TypeError, ValueError):
            return False
        if exp < self.clock():
            return False
        return hmac.compare_digest(sig or "", self._signature(event_id, name, exp))
