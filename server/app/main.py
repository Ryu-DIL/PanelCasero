import os
import secrets
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from .lights import LightError, LightManager, Unsupported

CONFIG_PATH = os.environ.get("PANEL_CONFIG", "/config/devices.json")


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


def require_token(authorization: str = Header(default="")):
    token = os.environ.get("PANEL_TOKEN", "")
    expected = f"Bearer {token}".encode()
    if not token or not secrets.compare_digest(authorization.encode(), expected):
        raise HTTPException(status_code=401, detail="Token no válido")


def create_app(manager: LightManager = None) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if not os.environ.get("PANEL_TOKEN"):
            raise RuntimeError("Falta PANEL_TOKEN en el archivo .env")
        app.state.lights = manager or LightManager.from_file(CONFIG_PATH)
        app.state.lights.start()
        yield
        app.state.lights.stop()

    app = FastAPI(title="PanelCasero", lifespan=lifespan)

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

    @app.get("/health")
    def health():
        return {"ok": True}

    @app.get("/api/lights", dependencies=[Depends(require_token)])
    def list_lights():
        return app.state.lights.snapshot()

    @app.get("/api/lights/{light_id}", dependencies=[Depends(require_token)])
    def one_light(light_id: str):
        return get_light(light_id).to_dict()

    @app.post("/api/lights/{light_id}/power", dependencies=[Depends(require_token)])
    def power(light_id: str, body: PowerBody):
        light = get_light(light_id)
        return run(light, light.set_power, body.on)

    @app.post("/api/lights/{light_id}/color", dependencies=[Depends(require_token)])
    def color(light_id: str, body: ColorBody):
        light = get_light(light_id)
        return run(light, light.set_color, body.hue, body.saturation, body.brightness)

    @app.post("/api/lights/{light_id}/white", dependencies=[Depends(require_token)])
    def white(light_id: str, body: WhiteBody):
        light = get_light(light_id)
        return run(light, light.set_white, body.brightness, body.temperature)

    @app.post("/api/lights/{light_id}/brightness", dependencies=[Depends(require_token)])
    def brightness(light_id: str, body: BrightnessBody):
        light = get_light(light_id)
        return run(light, light.set_brightness, body.brightness)

    return app


app = create_app()
