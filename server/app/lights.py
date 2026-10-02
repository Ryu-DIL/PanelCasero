"""Control local de las luces Tuya (bombilla y tira LED) con tinytuya.

Cada luz guarda su último estado conocido en memoria. Un hilo lo refresca
cada pocos segundos, de modo que el panel refleja los cambios hechos desde
otras apps (Tuya, Alexa...).
"""
import json
import logging
import threading

import tinytuya

log = logging.getLogger("panelcasero.lights")


class LightError(Exception):
    """No se pudo hablar con la luz (apagada, sin Wi-Fi, clave incorrecta...)."""


class Unsupported(Exception):
    """La luz no tiene esa función (por ejemplo, la tira LED no tiene modo blanco)."""


def default_factory(cfg):
    dev = tinytuya.BulbDevice(
        dev_id=cfg["tuya_id"],
        address=cfg["ip"],
        local_key=cfg["local_key"],
        version=float(cfg.get("version", 3.3)),
    )
    dev.set_socketTimeout(4)
    dev.set_socketRetryLimit(2)
    return dev


def _is_error(result):
    return isinstance(result, dict) and ("Error" in result or "Err" in result)


class Light:
    def __init__(self, cfg, device_factory=default_factory):
        self.id = cfg["id"]
        self.name = cfg.get("name", self.id)
        self.kind = cfg.get("kind", "bulb")
        self._cfg = cfg
        self._factory = device_factory
        self._dev = None
        self.lock = threading.Lock()
        self.state = {
            "online": False,
            "on": False,
            "mode": None,
            "brightness": 100.0,
            "temperature": 50.0,
            "hue": 0.0,
            "saturation": 100.0,
            "supports_color": True,
            "supports_white": True,
            "supports_white_temp": True,
        }

    # ---------- lectura ----------
    def _device(self):
        if self._dev is None:
            self._dev = self._factory(self._cfg)
        return self._dev

    def refresh(self, blocking=True):
        if not self.lock.acquire(blocking=blocking):
            return
        try:
            self._refresh_locked()
        finally:
            self.lock.release()

    def _refresh_locked(self):
        try:
            dev = self._device()
            raw = dev.state()
            if not isinstance(raw, dict) or _is_error(raw):
                raise LightError(str(raw))
            self.state = self._parse(dev, raw)
        except Exception as exc:  # noqa: BLE001 - cualquier fallo = luz sin conexión
            if self.state.get("online"):
                log.warning("%s sin conexión: %s", self.id, exc)
            self.state = {**self.state, "online": False}

    def _parse(self, dev, raw):
        has_colour = dev.bulb_has_capability("colour")
        has_temp = dev.bulb_has_capability("colourtemp")
        has_bright = dev.bulb_has_capability("brightness")

        new = dict(self.state)
        new["online"] = True
        new["on"] = bool(raw.get("is_on", raw.get("switch")))
        new["mode"] = raw.get("mode")
        new["supports_color"] = bool(has_colour)
        new["supports_white"] = bool(has_bright)
        new["supports_white_temp"] = bool(has_temp)

        value = None
        if has_colour and raw.get("colour"):
            hsv = dev.colour_hsv(state=raw)
            if isinstance(hsv, (tuple, list)) and len(hsv) == 3:
                new["hue"] = round(hsv[0] * 360, 1)
                new["saturation"] = round(hsv[1] * 100, 1)
                value = hsv[2] * 100

        white = None
        if has_bright and raw.get("brightness") is not None:
            white = dev.get_brightness_percentage(state=raw)
        if has_temp and raw.get("colourtemp") is not None:
            new["temperature"] = round(dev.get_colourtemp_percentage(state=raw), 1)

        if new["mode"] == "colour" and value is not None:
            new["brightness"] = round(value, 1)
        elif white is not None:
            new["brightness"] = round(white, 1)
        elif value is not None:
            new["brightness"] = round(value, 1)
        return new

    # ---------- escritura ----------
    def _command(self, action, update):
        with self.lock:
            try:
                result = action(self._device())
                if _is_error(result):
                    raise LightError(str(result))
            except Exception as exc:  # noqa: BLE001
                self.state = {**self.state, "online": False}
                raise LightError(str(exc)) from exc
            self.state = {**self.state, "online": True, **update}

    def set_power(self, on):
        self._command(lambda d: d.turn_on() if on else d.turn_off(), {"on": bool(on)})

    def set_color(self, hue, saturation, brightness):
        if not self.state.get("supports_color"):
            raise Unsupported("esta luz no admite color")
        self._command(
            lambda d: d.set_hsv(hue / 360.0, saturation / 100.0, brightness / 100.0),
            {"on": True, "mode": "colour", "hue": hue,
             "saturation": saturation, "brightness": brightness},
        )

    def set_white(self, brightness, temperature):
        if not self.state.get("supports_white"):
            raise Unsupported("esta luz no tiene modo blanco")
        self._command(
            lambda d: d.set_white_percentage(int(brightness), int(temperature)),
            {"on": True, "mode": "white", "brightness": brightness,
             "temperature": temperature},
        )

    def set_brightness(self, brightness):
        if self.state.get("mode") == "colour":
            hue, sat = self.state["hue"], self.state["saturation"]
            self._command(
                lambda d: d.set_hsv(hue / 360.0, sat / 100.0, brightness / 100.0),
                {"on": True, "brightness": brightness},
            )
        else:
            self._command(
                lambda d: d.set_brightness_percentage(int(brightness)),
                {"on": True, "brightness": brightness},
            )

    def to_dict(self):
        return {"id": self.id, "name": self.name, "kind": self.kind, **self.state}


class LightManager:
    def __init__(self, lights, interval=5.0):
        self.lights = {light.id: light for light in lights}
        self.interval = interval
        self._stop = threading.Event()
        self._thread = None

    @classmethod
    def from_file(cls, path, device_factory=default_factory):
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        return cls([Light(c, device_factory) for c in data["lights"]])

    def get(self, light_id):
        return self.lights.get(light_id)

    def snapshot(self):
        return [light.to_dict() for light in self.lights.values()]

    def start(self):
        if self._thread:
            return
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()

    def _loop(self):
        while not self._stop.is_set():
            for light in self.lights.values():
                light.refresh(blocking=False)
            self._stop.wait(self.interval)
