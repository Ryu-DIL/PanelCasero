import base64
import json
import os
import tempfile
import time
import uuid
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient

from app.camera import CameraMonitor
from app.config import Settings
from app.events import EventStore
from app.lights import Light, LightManager
from app.main import create_app

DEVICE = {"Authorization": "Bearer clave-del-iphone"}
JPEG = b"\xff\xd8\xff\xe0" + b"0" * 200
MP4 = b"\x00\x00\x00\x18ftypmp42" + b"0" * 200


class FakeResponse:
    def __init__(self, status):
        self.status_code = status
        self.text = ""
        self.reason = "Gone" if status == 410 else "OK"
        self.headers = {}
        self.ok = status < 400

    def raise_for_status(self):
        pass


class FakeSession:
    """Sustituye a `requests`: guarda los envíos push en vez de hacerlos."""

    def __init__(self):
        self.sent = []
        self.status = 201

    def post(self, endpoint, timeout=None, **params):
        self.sent.append({"endpoint": endpoint, "headers": params.get("headers", {})})
        return FakeResponse(self.status)


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def browser_subscription(endpoint="https://push.example/abc"):
    """Genera una suscripción push como la de un navegador (claves reales)."""
    key = ec.generate_private_key(ec.SECP256R1())
    public = key.public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    return {"endpoint": endpoint, "keys": {"p256dh": b64(public), "auth": b64(os.urandom(16))}}


def make_client():
    settings = Settings(token="clave-del-iphone", pin="1234",
                        data_dir=Path(tempfile.mkdtemp()), background=False)
    light = Light({"id": "tira", "name": "Tira"}, device_factory=lambda c: None)
    app = create_app(LightManager([light], interval=3600), settings)
    return TestClient(app), app


def login(client, pin="1234"):
    return client.post("/api/auth/login", json={"pin": pin})


def new_event(client, kind="alert", created=None):
    event_id = str(uuid.uuid4())
    body = {"kind": kind}
    if created:
        body["created"] = created
    assert client.put(f"/api/device/events/{event_id}", json=body, headers=DEVICE).status_code == 200
    return event_id


# ---------------- autenticación ----------------
def test_login_and_session():
    client, _ = make_client()
    with client:
        assert client.get("/api/auth/info").json() == {"pin_length": 4}
        assert client.get("/api/events").status_code == 401
        assert login(client, "0000").status_code == 401
        assert login(client).status_code == 200
        assert client.get("/api/auth/me").status_code == 200
        assert client.get("/api/events").status_code == 200
        client.post("/api/auth/logout")
        assert client.get("/api/events").status_code == 401


def test_lockout_after_five_wrong_pins():
    client, _ = make_client()
    with client:
        codes = [login(client, "9999").status_code for _ in range(5)]
        assert codes == [401, 401, 401, 401, 429]
        assert login(client).status_code == 429          # incluso el PIN bueno, mientras dure el bloqueo


def test_device_endpoints_need_token():
    client, _ = make_client()
    with client:
        assert client.post("/api/device/heartbeat", json={}).status_code == 401
        assert client.put(f"/api/device/events/{uuid.uuid4()}", json={}).status_code == 401


# ---------------- eventos y archivos ----------------
def test_event_flow_with_push_and_media():
    client, app = make_client()
    with client:
        session = FakeSession()
        app.state.push.session = session
        login(client)
        sub = browser_subscription()
        assert client.post("/api/push/subscribe", json={"subscription": sub, "lang": "ca"}).status_code == 200

        event_id = new_event(client)
        r = client.put(f"/api/device/events/{event_id}/photo", content=JPEG, headers=DEVICE)
        assert r.status_code == 200
        assert len(session.sent) == 1                            # aviso al subir la foto
        assert session.sent[0]["endpoint"] == sub["endpoint"]
        assert session.sent[0]["headers"].get("Urgency") == "high"

        # reenviar la foto no avisa dos veces
        client.put(f"/api/device/events/{event_id}/photo", content=JPEG, headers=DEVICE)
        assert len(session.sent) == 1

        assert client.put(f"/api/device/events/{event_id}/clip", content=MP4, headers=DEVICE).status_code == 200
        listed = client.get("/api/events").json()
        assert listed[0]["id"] == event_id and listed[0]["photo"] and listed[0]["clip"]

        assert client.get(f"/api/events/{event_id}/photo").content == JPEG
        assert client.get(f"/api/events/{event_id}/clip").headers["content-type"] == "video/mp4"

        assert client.delete(f"/api/events/{event_id}").status_code == 200
        assert client.get(f"/api/events/{event_id}/photo").status_code == 401 or \
            client.get(f"/api/events/{event_id}/photo").status_code == 404


def test_signed_url_works_without_login_and_rejects_tampering():
    client, app = make_client()
    with client:
        event_id = new_event(client)
        client.put(f"/api/device/events/{event_id}/photo", content=JPEG, headers=DEVICE)
        url = app.state.events.signed_url(event_id, "photo")
        anonymous = TestClient(app)
        assert anonymous.get(url).status_code == 200
        assert anonymous.get(url.replace("sig=", "sig=0")).status_code == 401
        assert anonymous.get(f"/api/events/{event_id}/photo").status_code == 401
        other = new_event(client)
        client.put(f"/api/device/events/{other}/photo", content=JPEG, headers=DEVICE)
        assert anonymous.get(url.replace(event_id, other)).status_code == 401


def test_rejects_bad_uploads():
    client, _ = make_client()
    with client:
        event_id = new_event(client)
        put = lambda name, data: client.put(f"/api/device/events/{event_id}/{name}",
                                            content=data, headers=DEVICE).status_code
        assert put("photo", b"esto no es una imagen") == 400
        assert put("clip", b"esto no es un video") == 400
        assert put("photo", b"") == 400
        assert client.put(f"/api/device/events/{uuid.uuid4()}/photo", content=JPEG,
                          headers=DEVICE).status_code == 404
        assert client.put("/api/device/events/../photo", content=JPEG, headers=DEVICE).status_code in (400, 404, 405)
        assert client.put("/api/device/events/no-es-uuid", json={"kind": "alert"},
                          headers=DEVICE).status_code == 400
        assert client.put(f"/api/device/events/{uuid.uuid4()}", json={"kind": "offline"},
                          headers=DEVICE).status_code == 400


def test_retention_cleanup():
    client, app = make_client()
    with client:
        old = new_event(client, created=time.time() - 40 * 86400)
        client.put(f"/api/device/events/{old}/photo", content=JPEG, headers=DEVICE)
        recent = new_event(client, created=time.time() - 5 * 86400)
        assert app.state.events.cleanup(30) == 1
        assert app.state.events.get(old) is None
        assert not app.state.events.path(old, "photo").exists()
        assert app.state.events.get(recent) is not None


# ---------------- cámara: latido ----------------
def test_camera_offline_and_recovered_notifications():
    client, app = make_client()
    with client:
        clock = {"t": 1000.0}
        session = FakeSession()
        app.state.push.session = session
        app.state.push.subscribe(**{"endpoint": "https://push.example/x", "p256dh": browser_subscription()["keys"]["p256dh"],
                                    "auth": browser_subscription()["keys"]["auth"]})
        monitor = CameraMonitor(app.state.events, app.state.push, offline_after=180, clock=lambda: clock["t"])

        monitor.check()                                           # sin señales aún: no avisa
        assert session.sent == []
        monitor.heartbeat(battery=0.8, charging=True, armed=False)
        clock["t"] += 100
        monitor.check()
        assert session.sent == [] and monitor.status()["online"] is True
        clock["t"] += 100                                         # 200 s sin latido
        monitor.check()
        assert len(session.sent) == 1 and monitor.status()["online"] is False
        monitor.check()                                           # no repite el aviso
        assert len(session.sent) == 1
        monitor.heartbeat()
        assert len(session.sent) == 2 and monitor.status()["online"] is True
        kinds = [e["kind"] for e in app.state.events.list()]
        assert "offline" in kinds and "recovered" in kinds


def test_heartbeat_endpoint_and_status():
    client, _ = make_client()
    with client:
        login(client)
        assert client.get("/api/status").json()["camera"]["known"] is False
        r = client.post("/api/device/heartbeat", json={"battery": 0.55, "charging": True, "armed": True},
                        headers=DEVICE)
        assert r.status_code == 200
        camera = client.get("/api/status").json()["camera"]
        assert camera["online"] and camera["battery"] == 0.55 and camera["armed"] is True
        assert client.post("/api/device/heartbeat", json={"battery": 5}, headers=DEVICE).status_code == 422


# ---------------- push ----------------
def test_push_key_subscribe_and_expired_subscription_removed():
    client, app = make_client()
    with client:
        login(client)
        key = client.get("/api/push/key").json()["key"]
        assert len(base64.urlsafe_b64decode(key + "==")) == 65      # punto P-256 sin comprimir
        bad = {"endpoint": "http://inseguro", "keys": {"p256dh": "a", "auth": "b"}}
        assert client.post("/api/push/subscribe", json={"subscription": bad}).status_code == 400

        session = FakeSession()
        app.state.push.session = session
        client.post("/api/push/subscribe", json={"subscription": browser_subscription(), "lang": "de"})
        assert client.post("/api/push/test").json()["devices"] == 1
        assert len(session.sent) == 1

        session.status = 410                                       # el navegador dio de baja la suscripción
        client.post("/api/push/test")
        assert app.state.push.count() == 0


def test_vapid_keys_are_persistent():
    client, app = make_client()
    with client:
        first = app.state.push.public_key
    from app.push import PushService
    again = PushService(app.state.db, app.state.cfg.data_dir, "mailto:a@b.c", background=False)
    assert again.public_key == first


def test_web_app_is_served():
    client, _ = make_client()
    with client:
        assert client.get("/health").json() == {"ok": True}
        r = client.get("/")
        assert r.status_code == 200 and r.headers["cache-control"] == "no-cache"


def test_get_single_event():
    client, _ = make_client()
    with client:
        event_id = new_event(client)
        assert client.get(f"/api/events/{event_id}").status_code == 401     # sin sesión
        login(client)
        body = client.get(f"/api/events/{event_id}").json()
        assert body["id"] == event_id and body["photo"] is False
        assert client.get(f"/api/events/{uuid.uuid4()}").status_code == 404
        assert client.get("/api/events/no-es-uuid").status_code == 404
