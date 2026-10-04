import base64
import json
import logging
import threading
import time
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from py_vapid import Vapid
from pywebpush import WebPushException, webpush

log = logging.getLogger("panelcasero.push")

MESSAGES = {
    "alert": {
        "es": ("Movimiento detectado", "Se ha detectado movimiento en la habitación."),
        "ca": ("Moviment detectat", "S'ha detectat moviment a l'habitació."),
        "en": ("Motion detected", "Motion was detected in the room."),
        "de": ("Bewegung erkannt", "Im Raum wurde eine Bewegung erkannt."),
    },
    "alert_pin": {
        "es": ("PIN incorrecto en el panel", "Se han introducido varios PIN incorrectos en el panel."),
        "ca": ("PIN incorrecte al panell", "S'han introduït diversos PIN incorrectes al panell."),
        "en": ("Wrong PIN on the panel", "Several wrong PINs were entered on the panel."),
        "de": ("Falsche PIN am Panel", "Am Panel wurden mehrere falsche PINs eingegeben."),
    },
    "test": {
        "es": ("Notificación de prueba", "Las notificaciones funcionan correctamente."),
        "ca": ("Notificació de prova", "Les notificacions funcionen correctament."),
        "en": ("Test notification", "Notifications are working."),
        "de": ("Testbenachrichtigung", "Benachrichtigungen funktionieren."),
    },
    "offline": {
        "es": ("Cámara desconectada", "El iPhone de la cámara no responde."),
        "ca": ("Càmera desconnectada", "L'iPhone de la càmera no respon."),
        "en": ("Camera offline", "The camera iPhone is not responding."),
        "de": ("Kamera offline", "Das Kamera-iPhone antwortet nicht."),
    },
    "recovered": {
        "es": ("Cámara reconectada", "El iPhone de la cámara vuelve a responder."),
        "ca": ("Càmera reconnectada", "L'iPhone de la càmera torna a respondre."),
        "en": ("Camera back online", "The camera iPhone is responding again."),
        "de": ("Kamera wieder online", "Das Kamera-iPhone antwortet wieder."),
    },
}
LANGS = ("es", "ca", "en", "de")


class PushService:
    """Notificaciones push web (VAPID). Las claves se generan solas la primera vez."""

    def __init__(self, db, data_dir, subject, background=True, session=None):
        self.db = db
        self.subject = subject
        self.background = background
        self.session = session       # solo para pruebas
        key_path = Path(data_dir) / "vapid_private.pem"
        key_path.parent.mkdir(parents=True, exist_ok=True)
        if key_path.exists():
            self.vapid = Vapid.from_file(str(key_path))
        else:
            self.vapid = Vapid()
            self.vapid.generate_keys()
            self.vapid.save_key(str(key_path))
            key_path.chmod(0o600)
        raw = self.vapid.public_key.public_bytes(
            serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint
        )
        self.public_key = base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

    # ---- suscripciones ----
    def subscribe(self, endpoint, p256dh, auth, lang="es"):
        lang = lang if lang in LANGS else "es"
        self.db.execute(
            "INSERT INTO push_subs(endpoint, p256dh, auth, lang, created) VALUES(?,?,?,?,?) "
            "ON CONFLICT(endpoint) DO UPDATE SET p256dh=excluded.p256dh, "
            "auth=excluded.auth, lang=excluded.lang",
            (endpoint, p256dh, auth, lang, time.time()),
        )

    def unsubscribe(self, endpoint):
        self.db.execute("DELETE FROM push_subs WHERE endpoint = ?", (endpoint,))

    def count(self) -> int:
        return len(self.db.query("SELECT endpoint FROM push_subs"))

    # ---- envío ----
    def notify(self, kind, event_id=None, image=None, created=None, reason=None):
        """Avisa a todos los dispositivos suscritos (en segundo plano si procede)."""
        if self.background:
            threading.Thread(
                target=self._notify_all, args=(kind, event_id, image, created, reason), daemon=True
            ).start()
        else:
            self._notify_all(kind, event_id, image, created, reason)

    def _notify_all(self, kind, event_id, image, created, reason=None):
        key = "alert_pin" if kind == "alert" and reason == "pin" else kind
        for sub in self.db.query("SELECT * FROM push_subs"):
            title, body = MESSAGES[key].get(sub["lang"], MESSAGES[key]["es"])
            payload = {
                "kind": kind,
                "title": title,
                "body": body,
                "tag": kind,
                "url": f"/#event={event_id}" if event_id else "/",
                "image": image,
                "ts": created or time.time(),
            }
            self._deliver(sub, payload, urgent=kind in ("alert", "offline"))

    def _deliver(self, sub, payload, urgent=False):
        info = {"endpoint": sub["endpoint"], "keys": {"p256dh": sub["p256dh"], "auth": sub["auth"]}}
        try:
            webpush(
                subscription_info=info,
                data=json.dumps(payload),
                vapid_private_key=self.vapid,
                vapid_claims={"sub": self.subject},
                ttl=86400,                      # si el móvil está sin red, se entrega al volver
                headers={"Urgency": "high" if urgent else "normal"},
                requests_session=self.session,
                timeout=10,
            )
        except WebPushException as exc:
            status = getattr(exc.response, "status_code", None)
            if status in (404, 410):
                log.info("Suscripción caducada, se elimina")
                self.unsubscribe(sub["endpoint"])
            else:
                log.warning("No se pudo enviar la notificación: %s", exc)
        except Exception as exc:  # noqa: BLE001
            log.warning("Fallo inesperado al enviar la notificación: %s", exc)
