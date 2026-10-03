import hashlib
import secrets
import threading
import time


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


class Auth:
    """Clave del dispositivo (iPhone) y PIN + sesiones para la web."""

    MAX_FAILS = 5
    LOCK_SECONDS = 900          # bloqueo de 15 min tras 5 PIN erróneos
    SESSION_SECONDS = 30 * 86400

    def __init__(self, db, pin, token, clock=time.time):
        self.db = db
        self.pin = pin
        self.token = token
        self.clock = clock
        self._lock = threading.Lock()
        self._fails = 0
        self._locked_until = 0.0

    # ---- iPhone ----
    def check_device(self, header: str) -> bool:
        expected = f"Bearer {self.token}".encode()
        return secrets.compare_digest((header or "").encode(), expected)

    # ---- Web ----
    def try_login(self, pin: str):
        """Devuelve (ok, segundos_de_bloqueo). Bloqueo > 0 significa 'espera'."""
        with self._lock:
            now = self.clock()
            if self._locked_until > now:
                return False, int(self._locked_until - now) + 1
            if secrets.compare_digest((pin or "").encode(), self.pin.encode()):
                self._fails = 0
                return True, 0
            self._fails += 1
            if self._fails >= self.MAX_FAILS:
                self._fails = 0
                self._locked_until = now + self.LOCK_SECONDS
                return False, self.LOCK_SECONDS
            return False, 0

    def create_session(self) -> str:
        token = secrets.token_urlsafe(32)
        now = self.clock()
        self.db.execute("DELETE FROM sessions WHERE expires < ?", (now,))
        self.db.execute(
            "INSERT INTO sessions(token_hash, expires) VALUES(?, ?)",
            (_hash(token), now + self.SESSION_SECONDS),
        )
        return token

    def valid_session(self, token) -> bool:
        if not token:
            return False
        row = self.db.one("SELECT expires FROM sessions WHERE token_hash = ?", (_hash(token),))
        return bool(row) and row["expires"] > self.clock()

    def end_session(self, token):
        if token:
            self.db.execute("DELETE FROM sessions WHERE token_hash = ?", (_hash(token),))
