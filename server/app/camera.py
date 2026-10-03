import logging
import threading
import time
import uuid

log = logging.getLogger("panelcasero.camera")


class CameraMonitor:
    """Sigue los latidos del iPhone y avisa si deja de responder."""

    def __init__(self, events, push, offline_after=180.0, clock=time.time):
        self.events = events
        self.push = push
        self.offline_after = offline_after
        self.clock = clock
        self._lock = threading.Lock()
        self.online = None            # None = aún no ha dado señales
        self.last_seen = None
        self.battery = None
        self.charging = None
        self.armed = None

    def heartbeat(self, battery=None, charging=None, armed=None):
        recovered = False
        with self._lock:
            self.last_seen = self.clock()
            self.battery = battery
            self.charging = charging
            self.armed = armed
            if self.online is False:
                recovered = True
            self.online = True
        if recovered:
            self._announce("recovered")

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

    def _announce(self, kind):
        event_id = str(uuid.uuid4())
        self.events.upsert(event_id, kind)
        self.push.notify(kind, event_id=event_id)

    def status(self):
        with self._lock:
            return {
                "online": bool(self.online),
                "known": self.online is not None,
                "last_seen": self.last_seen,
                "battery": self.battery,
                "charging": self.charging,
                "armed": self.armed,
            }
