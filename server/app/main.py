import logging
import mimetypes
import threading
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from .auth import Auth
from .camera import CameraMonitor
from .config import Settings
from .db import Database
from .events import (DEVICE_KINDS, MAX_BYTES, MEDIA, NOTIFY_KINDS, REASONS, EventStore,
                     looks_like, valid_id)
from .lights import LightError, LightManager, Unsupported
from .push import PushService

log = logging.getLogger("panelcasero")
CONFIG_PATH = "/config/devices.json"
STATIC_DIR = Path(__file__).parent / "static"
SESSION_COOKIE = "session"

mimetypes.add_type("application/manifest+json", ".webmanifest")


# ---------- cuerpos de las peticiones ----------
class PowerBody(BaseModel):
    on: bool


class ColorBody(BaseModel):
    hue: float = Field(ge=0, le=360)
    saturation: float = Field(ge=0, le=100)
    brightness: float = Field(ge=1, le=100)


class WhiteBody(BaseModel):
    brightness: float = Field(ge=1, le=100)
    temperature: float = Field(ge=0, le=100)


class BrightnessBody(BaseModel):
    brightness: float = Field(ge=1, le=100)


class EventBody(BaseModel):
    kind: str = "alert"
    created: Optional[float] = None
    reason: Optional[str] = None


class HeartbeatBody(BaseModel):
    battery: Optional[float] = Field(default=None, ge=0, le=1)
    charging: Optional[bool] = None
    armed: Optional[bool] = None
    alarm: Optional[str] = Field(default=None, pattern="^(disarmed|exiting|armed|entry)$")
    thermal: Optional[str] = Field(default=None, pattern="^(nominal|fair|serious|critical)$")


class LoginBody(BaseModel):
    pin: str = Field(max_length=16)


class SubscribeBody(BaseModel):
    subscription: dict
    lang: str = "es"


class UnsubscribeBody(BaseModel):
    endpoint: str


def _is_https(request: Request) -> bool:
    return request.url.scheme == "https" or request.headers.get("x-forwarded-proto") == "https"


def _loop(stop: threading.Event, interval: float, fn):
    while not stop.wait(interval):
        try:
            fn()
        except Exception:  # noqa: BLE001
            log.exception("Error en una tarea periódica")


def create_app(manager: LightManager = None, settings: Settings = None) -> FastAPI:
    stop = threading.Event()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        cfg = settings or Settings.from_env()
        db = Database(cfg.data_dir / "panelcasero.db")
        events = EventStore(db, cfg.data_dir / "events")
        push = PushService(db, cfg.data_dir, cfg.vapid_subject, background=cfg.background)
        app.state.cfg = cfg
        app.state.db = db
        app.state.auth = Auth(db, cfg.pin, cfg.token)
        app.state.events = events
        app.state.push = push
        app.state.camera = CameraMonitor(events, push, cfg.offline_after,
                                         low_battery=cfg.low_battery,
                                         power_lost_after=cfg.power_lost_after)
        app.state.lights = manager or LightManager.from_file(CONFIG_PATH)
        app.state.lights.start()
        if cfg.background:
            events.cleanup(cfg.retention_days)
            threading.Thread(target=_loop, args=(stop, 20, app.state.camera.check), daemon=True).start()
            threading.Thread(
                target=_loop, args=(stop, 6 * 3600, lambda: events.cleanup(cfg.retention_days)),
                daemon=True,
            ).start()
        yield
        stop.set()
        app.state.lights.stop()

    app = FastAPI(title="PanelCasero", lifespan=lifespan)

    # ---------- autenticación ----------
    def bearer_ok(request: Request) -> bool:
        return app.state.auth.check_device(request.headers.get("authorization", ""))

    def session_ok(request: Request) -> bool:
        return app.state.auth.valid_session(request.cookies.get(SESSION_COOKIE))

    def need_device(request: Request):
        if not bearer_ok(request):
            raise HTTPException(status_code=401, detail="Token no válido")

    def need_user(request: Request):
        if not session_ok(request):
            raise HTTPException(status_code=401, detail="Sesión no válida")

    def need_any(request: Request):
        if not (bearer_ok(request) or session_ok(request)):
            raise HTTPException(status_code=401, detail="Token no válido")

    @app.middleware("http")
    async def no_cache_for_web(request: Request, call_next):
        response = await call_next(request)
        if not request.url.path.startswith("/api/"):
            response.headers["Cache-Control"] = "no-cache"
        return response

    @app.get("/health")
    def health():
        return {"ok": True}

    @app.get("/api/auth/info")
    def auth_info():
        return {"pin_length": len(app.state.cfg.pin)}

    @app.post("/api/auth/login")
    def login(body: LoginBody, request: Request, response: Response):
        ok, locked = app.state.auth.try_login(body.pin)
        if locked:
            raise HTTPException(status_code=429, detail={"retry_after": locked})
        if not ok:
            raise HTTPException(status_code=401, detail="PIN incorrecto")
        token = app.state.auth.create_session()
        response.set_cookie(
            SESSION_COOKIE, token, max_age=app.state.auth.SESSION_SECONDS,
            httponly=True, samesite="strict", secure=_is_https(request), path="/",
        )
        return {"ok": True}

    @app.post("/api/auth/logout")
    def logout(request: Request, response: Response):
        app.state.auth.end_session(request.cookies.get(SESSION_COOKIE))
        response.delete_cookie(SESSION_COOKIE, path="/")
        return {"ok": True}

    @app.get("/api/auth/me", dependencies=[Depends(need_user)])
    def me():
        return {"ok": True}

    # ---------- luces ----------
    def get_light(light_id: str):
        light = app.state.lights.get(light_id)
        if light is None:
            raise HTTPException(status_code=404, detail="Luz desconocida")
        return light

    def run(light, fn, *args):
        try:
            fn(*args)
        except Unsupported as exc:
            raise HTTPException(status_code=400, detail=str(exc))
        except LightError as exc:
            raise HTTPException(status_code=502, detail=f"No responde: {exc}")
        return light.to_dict()

    @app.get("/api/lights", dependencies=[Depends(need_any)])
    def list_lights():
        return app.state.lights.snapshot()

    @app.get("/api/lights/{light_id}", dependencies=[Depends(need_any)])
    def one_light(light_id: str):
        return get_light(light_id).to_dict()

    @app.post("/api/lights/{light_id}/power", dependencies=[Depends(need_any)])
    def power(light_id: str, body: PowerBody):
        light = get_light(light_id)
        return run(light, light.set_power, body.on)

    @app.post("/api/lights/{light_id}/color", dependencies=[Depends(need_any)])
    def color(light_id: str, body: ColorBody):
        light = get_light(light_id)
        return run(light, light.set_color, body.hue, body.saturation, body.brightness)

    @app.post("/api/lights/{light_id}/white", dependencies=[Depends(need_any)])
    def white(light_id: str, body: WhiteBody):
        light = get_light(light_id)
        return run(light, light.set_white, body.brightness, body.temperature)

    @app.post("/api/lights/{light_id}/brightness", dependencies=[Depends(need_any)])
    def brightness(light_id: str, body: BrightnessBody):
        light = get_light(light_id)
        return run(light, light.set_brightness, body.brightness)

    # ---------- iPhone: latido y eventos ----------
    @app.post("/api/device/heartbeat", dependencies=[Depends(need_device)])
    def heartbeat(body: HeartbeatBody):
        app.state.camera.heartbeat(body.battery, body.charging, body.armed, body.alarm, body.thermal)
        return {"ok": True, "server_time": time.time()}

    @app.put("/api/device/events/{event_id}", dependencies=[Depends(need_device)])
    def put_event(event_id: str, body: EventBody):
        if not valid_id(event_id):
            raise HTTPException(status_code=400, detail="Identificador no válido")
        if body.kind not in DEVICE_KINDS:
            raise HTTPException(status_code=400, detail="Tipo de evento no válido")
        if body.reason is not None and body.reason not in REASONS:
            raise HTTPException(status_code=400, detail="Motivo no válido")
        return app.state.events.upsert(event_id, body.kind, body.created, body.reason)

    async def put_media(event_id: str, name: str, request: Request):
        events = app.state.events
        if not valid_id(event_id):
            raise HTTPException(status_code=400, detail="Identificador no válido")
        event = events.get(event_id)
        if event is None:
            raise HTTPException(status_code=404, detail="Evento desconocido")
        declared = request.headers.get("content-length")
        if declared and declared.isdigit() and int(declared) > MAX_BYTES[name]:
            raise HTTPException(status_code=413, detail="Archivo demasiado grande")
        data = await request.body()
        if not data or len(data) > MAX_BYTES[name] or not looks_like(name, data):
            raise HTTPException(status_code=400, detail="Archivo no válido")
        events.save_media(event_id, name, data)
        if name == "photo" and event["kind"] in NOTIFY_KINDS and events.claim_notification(event_id):
            app.state.push.notify(
                event["kind"], event_id=event_id,
                image=events.signed_url(event_id, "photo"), created=event["created"],
                reason=event.get("reason"),
            )
        return {"ok": True}

    @app.put("/api/device/events/{event_id}/photo", dependencies=[Depends(need_device)])
    async def put_photo(event_id: str, request: Request):
        return await put_media(event_id, "photo", request)

    @app.put("/api/device/events/{event_id}/clip", dependencies=[Depends(need_device)])
    async def put_clip(event_id: str, request: Request):
        return await put_media(event_id, "clip", request)

    # ---------- web: eventos ----------
    @app.get("/api/events", dependencies=[Depends(need_user)])
    def list_events(limit: int = 50, before: Optional[float] = None):
        return app.state.events.list(limit, before)

    @app.get("/api/events/{event_id}", dependencies=[Depends(need_user)])
    def one_event(event_id: str):
        event = app.state.events.get(event_id) if valid_id(event_id) else None
        if event is None:
            raise HTTPException(status_code=404, detail="No encontrado")
        return event

    @app.get("/api/events/{event_id}/{name}")
    def event_media(event_id: str, name: str, request: Request,
                    exp: Optional[str] = None, sig: Optional[str] = None):
        events = app.state.events
        if name not in MEDIA or not valid_id(event_id):
            raise HTTPException(status_code=404, detail="No encontrado")
        allowed = session_ok(request) or bearer_ok(request) or events.verify(event_id, name, exp, sig)
        if not allowed:
            raise HTTPException(status_code=401, detail="No autorizado")
        path = events.path(event_id, name)
        if not path.exists():
            raise HTTPException(status_code=404, detail="No encontrado")
        media_type = "image/jpeg" if name == "photo" else "video/mp4"
        return FileResponse(path, media_type=media_type)

    @app.delete("/api/events/{event_id}", dependencies=[Depends(need_user)])
    def delete_event(event_id: str):
        if not valid_id(event_id) or not app.state.events.delete(event_id):
            raise HTTPException(status_code=404, detail="No encontrado")
        return {"ok": True}

    # ---------- web: estado, cámara y notificaciones ----------
    @app.get("/api/status", dependencies=[Depends(need_user)])
    def status():
        return {
            "camera": app.state.camera.status(),
            "stream": bool(app.state.cfg.camera_url),
            "push_devices": app.state.push.count(),
            "server_time": time.time(),
        }

    def camera_request(path: str):
        base = app.state.cfg.camera_url
        if not base:
            raise HTTPException(status_code=503, detail="Falta PANEL_CAMERA_URL")
        return base + path, {"Authorization": f"Bearer {app.state.cfg.token}"}

    @app.get("/api/camera/snapshot", dependencies=[Depends(need_user)])
    async def camera_snapshot():
        url, headers = camera_request("/snapshot.jpg")
        try:
            async with httpx.AsyncClient(timeout=6) as client:
                reply = await client.get(url, headers=headers)
        except httpx.HTTPError:
            raise HTTPException(status_code=503, detail="La cámara no responde")
        if reply.status_code != 200:
            raise HTTPException(status_code=503, detail="La cámara no responde")
        return Response(reply.content, media_type="image/jpeg", headers={"Cache-Control": "no-store"})

    @app.get("/api/camera/stream", dependencies=[Depends(need_user)])
    async def camera_stream():
        url, headers = camera_request("/stream")
        client = httpx.AsyncClient(timeout=httpx.Timeout(6, read=None))
        try:
            upstream = await client.send(client.build_request("GET", url, headers=headers), stream=True)
        except httpx.HTTPError:
            await client.aclose()
            raise HTTPException(status_code=503, detail="La cámara no responde")
        if upstream.status_code != 200:
            await upstream.aclose()
            await client.aclose()
            raise HTTPException(status_code=503, detail="La cámara no responde")

        async def relay():
            try:
                async for chunk in upstream.aiter_raw():
                    yield chunk
            except httpx.HTTPError:
                pass
            finally:
                await upstream.aclose()
                await client.aclose()

        return StreamingResponse(
            relay(),
            media_type=upstream.headers.get("content-type", "multipart/x-mixed-replace"),
            headers={"Cache-Control": "no-store"},
        )

    @app.post("/api/alarm/{action}", dependencies=[Depends(need_user)])
    async def alarm_command(action: str):
        """Arma o desarma desde la web: se lo pide al iPhone, que es quien manda."""
        if action not in ("arm", "disarm"):
            raise HTTPException(status_code=404, detail="Orden desconocida")
        url, headers = camera_request(f"/alarm/{action}")
        try:
            async with httpx.AsyncClient(timeout=6) as client:
                reply = await client.post(url, headers=headers)
            state = reply.json().get("state") if reply.status_code == 200 else None
        except (httpx.HTTPError, ValueError):
            state = None
        if state not in ("disarmed", "exiting", "armed", "entry"):
            raise HTTPException(status_code=503, detail="La cámara no responde")
        app.state.camera.set_alarm(state)
        return {"alarm": state}

    @app.get("/api/push/key", dependencies=[Depends(need_user)])
    def push_key():
        return {"key": app.state.push.public_key}

    @app.post("/api/push/subscribe", dependencies=[Depends(need_user)])
    def push_subscribe(body: SubscribeBody):
        sub = body.subscription
        keys = sub.get("keys") or {}
        endpoint = sub.get("endpoint", "")
        if not str(endpoint).startswith("https://") or not keys.get("p256dh") or not keys.get("auth"):
            raise HTTPException(status_code=400, detail="Suscripción no válida")
        app.state.push.subscribe(endpoint, keys["p256dh"], keys["auth"], body.lang)
        return {"ok": True}

    @app.post("/api/push/unsubscribe", dependencies=[Depends(need_user)])
    def push_unsubscribe(body: UnsubscribeBody):
        app.state.push.unsubscribe(body.endpoint)
        return {"ok": True}

    @app.post("/api/push/test", dependencies=[Depends(need_user)])
    def push_test():
        app.state.push.notify("test")
        return {"ok": True, "devices": app.state.push.count()}

    # ---------- la web (PWA); debe ir la última ----------
    app.mount("/", StaticFiles(directory=STATIC_DIR, html=True), name="web")
    return app


app = create_app()
