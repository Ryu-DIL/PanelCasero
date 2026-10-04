import os
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Settings:
    token: str                       # clave del iPhone (cámara) con el servidor
    pin: str                         # PIN para entrar en la web (PWA)
    data_dir: Path = Path("/data")
    retention_days: int = 30
    camera_url: str = ""             # p. ej. http://192.168.1.181:8081
    vapid_subject: str = "mailto:admin@panelcasero.local"
    offline_after: float = 180.0     # segundos sin latido -> "cámara desconectada"
    low_battery: float = 0.20        # por debajo (y sin cargar) -> aviso de batería baja
    power_lost_after: float = 300.0  # segundos sin cargar -> aviso de corte de luz
    background: bool = True          # hilos de limpieza y vigilancia (se desactivan en tests)

    @classmethod
    def from_env(cls) -> "Settings":
        token = os.environ.get("PANEL_TOKEN", "")
        pin = os.environ.get("PANEL_PIN", "")
        if not token:
            raise RuntimeError("Falta PANEL_TOKEN en el archivo .env")
        if not pin.isdigit() or not 4 <= len(pin) <= 8:
            raise RuntimeError("PANEL_PIN debe tener entre 4 y 8 dígitos (archivo .env)")
        return cls(
            token=token,
            pin=pin,
            data_dir=Path(os.environ.get("PANEL_DATA", "/data")),
            retention_days=int(os.environ.get("PANEL_RETENTION_DAYS", "30")),
            camera_url=os.environ.get("PANEL_CAMERA_URL", "").rstrip("/"),
            vapid_subject=os.environ.get("PANEL_VAPID_SUBJECT", "mailto:admin@panelcasero.local"),
            low_battery=int(os.environ.get("PANEL_LOW_BATTERY_PERCENT", "20")) / 100,
            power_lost_after=float(os.environ.get("PANEL_POWER_LOST_MINUTES", "5")) * 60,
        )
