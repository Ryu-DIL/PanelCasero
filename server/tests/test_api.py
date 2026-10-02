import os

os.environ["PANEL_TOKEN"] = "secreto-de-prueba"

from fastapi.testclient import TestClient

from app.lights import Light, LightManager
from app.main import create_app

AUTH = {"Authorization": "Bearer secreto-de-prueba"}


class FakeBulb:
    """Imita lo justo de tinytuya.BulbDevice para probar la lógica."""

    def __init__(self, cfg, fail=False, caps=None):
        self.fail = fail
        self.caps = caps or {"colour", "colourtemp", "brightness"}
        self.on = False
        self.mode = "white"
        self.bri = 50
        self.temp = 20
        self.hsv = (0.5, 1.0, 1.0)

    def state(self):
        if self.fail:
            return {"Error": "Network Error: Unable to Connect", "Err": "901"}
        return {"is_on": self.on, "switch": self.on, "mode": self.mode,
                "brightness": self.bri * 10, "colourtemp": self.temp * 10,
                "colour": "x"}

    def bulb_has_capability(self, feature):
        return feature in self.caps

    def colour_hsv(self, state=None):
        return self.hsv

    def get_brightness_percentage(self, state=None):
        return state["brightness"] / 10

    def get_colourtemp_percentage(self, state=None):
        return state["colourtemp"] / 10

    def turn_on(self):
        self.on = True

    def turn_off(self):
        self.on = False

    def set_hsv(self, h, s, v):
        self.hsv, self.mode, self.on = (h, s, v), "colour", True

    def set_white_percentage(self, brightness, colourtemp):
        self.bri, self.temp, self.mode, self.on = brightness, colourtemp, "white", True

    def set_brightness_percentage(self, brightness):
        self.bri, self.on = brightness, True


def make_client(fail=False, caps=None):
    cfg = {"id": "tira", "name": "Tira LED", "kind": "strip"}
    light = Light(cfg, device_factory=lambda c: FakeBulb(c, fail, caps))
    manager = LightManager([light], interval=3600)
    return TestClient(create_app(manager)), light


def test_requires_token():
    with make_client()[0] as client:
        assert client.get("/health").status_code == 200
        assert client.get("/api/lights").status_code == 401
        assert client.get("/api/lights", headers={"Authorization": "Bearer mal"}).status_code == 401


def test_power_color_white_brightness():
    client, light = make_client()
    with client:
        light.refresh()
        data = client.get("/api/lights", headers=AUTH).json()
        assert data[0]["online"] is True and data[0]["on"] is False
        assert data[0]["brightness"] == 50 and data[0]["temperature"] == 20

        r = client.post("/api/lights/tira/power", json={"on": True}, headers=AUTH)
        assert r.status_code == 200 and r.json()["on"] is True

        r = client.post("/api/lights/tira/color",
                        json={"hue": 270, "saturation": 80, "brightness": 60}, headers=AUTH)
        body = r.json()
        assert body["mode"] == "colour" and body["hue"] == 270
        dev = light._dev
        assert dev.hsv == (270 / 360, 0.8, 0.6)

        client.post("/api/lights/tira/brightness", json={"brightness": 30}, headers=AUTH)
        assert dev.hsv == (270 / 360, 0.8, 0.3)

        r = client.post("/api/lights/tira/white",
                        json={"brightness": 70, "temperature": 40}, headers=AUTH)
        assert r.json()["mode"] == "white"
        assert (dev.bri, dev.temp) == (70, 40)

        client.post("/api/lights/tira/brightness", json={"brightness": 20}, headers=AUTH)
        assert dev.bri == 20


def test_validation_and_unknown_light():
    client, _ = make_client()
    with client:
        r = client.post("/api/lights/tira/color",
                        json={"hue": 500, "saturation": 80, "brightness": 60}, headers=AUTH)
        assert r.status_code == 422
        assert client.post("/api/lights/nada/power", json={"on": True}, headers=AUTH).status_code == 404


def test_offline_light():
    client, light = make_client(fail=True)
    with client:
        light.refresh()
        assert client.get("/api/lights", headers=AUTH).json()[0]["online"] is False
        r = client.post("/api/lights/tira/power", json={"on": True}, headers=AUTH)
        assert r.status_code == 200  # el FakeBulb falla solo al leer el estado


def test_strip_without_white_mode():
    """La tira LED real solo tiene color: sin brillo blanco ni temperatura."""
    client, light = make_client(caps={"colour"})
    with client:
        light.refresh()
        data = client.get("/api/lights", headers=AUTH).json()[0]
        assert data["supports_color"] is True
        assert data["supports_white"] is False
        assert data["supports_white_temp"] is False
        r = client.post("/api/lights/tira/white",
                        json={"brightness": 50, "temperature": 50}, headers=AUTH)
        assert r.status_code == 400
        r = client.post("/api/lights/tira/color",
                        json={"hue": 120, "saturation": 100, "brightness": 40}, headers=AUTH)
        assert r.status_code == 200


def test_bulb_without_color_rejects_color():
    client, light = make_client(caps={"brightness", "colourtemp"})
    with client:
        light.refresh()
        r = client.post("/api/lights/tira/color",
                        json={"hue": 120, "saturation": 100, "brightness": 40}, headers=AUTH)
        assert r.status_code == 400
