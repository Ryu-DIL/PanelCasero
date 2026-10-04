import logging
import threading
import time
import uuid

log = logging.getLogger("panelcasero.camera")


class CameraMonitor:
    """Sigue los latidos del iPhone y avisa si deja de responder."""

    def __init__(self, events, push, offline_after=180.0, clock=time.time,
                 low_battery=0.20, power_lost_after=300.0):
        self.events = events
        self.push = push
        self.offline_after = offline_after
        self.low_battery = low_battery
        self.power_lost_after = power_lost_after
        self.clock = clock
        self._lock = threading.Lock()
        self.online = None            # None = aún no ha dado señales
        self.last_seen = None
        self.battery = None
        self.charging = None
        self.armed = None
        self.alarm = None             # disarmed | exiting | armed | entry
        self.thermal = None           # nominal | fair | serious | critical
        self._low_alerted = False
        self._not_charging_since = None
        self._power_alerted = False
        self._hot_alerted = False

    def heartbeat(self, battery=None, charging=None, armed=None, alarm=None, thermal=None):
        recovered = False
        announcements = []
        with self._lock:
            now = self.clock()
            self.last_seen = now
            self.thermal = thermal
            self.battery = battery
            self.charging = charging
            if alarm is not None:
                self.alarm = alarm
                armed = alarm != "disarmed"
            self.armed = armed
            if self.online is False:
                recovered = True
            self.online = True

            # Batería baja (una sola vez hasta que se recupere o se ponga a cargar).
            if battery is not None:
                if battery <= self.low_battery and charging is not True and not self._low_alerted:
                    self._low_alerted = True
                    announcements.append(("battery_low", {"pct": round(battery * 100)}))
                elif battery >= self.low_battery + 0.10 or charging is True:
                    self._low_alerted = False

            # Corte de luz o cable suelto: lleva un rato sin cargar.
            if charging is False:
                if self._not_charging_since is None:
                    self._not_charging_since = now
                elif not self._power_alerted and now - self._not_charging_since >= self.power_lost_after:
                    self._power_alerted = True
                    announcements.append(("power_lost", None))
            elif charging is True:
                self._not_charging_since = None
                if self._power_alerted:
                    self._power_alerted = False
                    announcements.append(("power_restored", None))

            # Calentamiento del iPhone.
            if thermal in ("serious", "critical"):
                if not self._hot_alerted:
                    self._hot_alerted = True
                    announcements.append(("hot", None))
            elif thermal in ("nominal", "fair"):
                self._hot_alerted = False

        if recovered:
            self._announce("recovered")
        for kind, params in announcements:
            self._announce(kind, params)

    def check(self):
        """Se llama cada pocos segundos desde un hilo."""
        went_offline = False
        with self._lock:
            if self.online and self.last_seen is not None \
                    and self.clock() - self.last_seen > self.offline_after:
                self.online = False
                went_offline = True
        if went_offline:
            self._announce("offline")

    def _announce(self, kind, params=None):
        event_id = str(uuid.uuid4())
        self.events.upsert(event_id, kind)
        self.push.notify(kind, event_id=event_id, params=params)

    def status(self):
        with self._lock:
            return {
                "online": bool(self.online),
                "known": self.online is not None,
                "last_seen": self.last_seen,
                "battery": self.battery,
                "charging": self.charging,
                "armed": self.armed,
                "alarm": self.alarm,
                "thermal": self.thermal,
            }

    def set_alarm(self, alarm):
        """El iPhone acaba de contestar a una orden de armar o desarmar."""
        with self._lock:
            self.alarm = alarm
            self.armed = alarm != "disarmed"
