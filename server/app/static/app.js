'use strict';

/* ---------- Textos en 4 idiomas ---------- */
const I18N = {
  es: {
    enter_pin: 'Introduce el PIN', wrong_pin: 'PIN incorrecto', locked: 'Demasiados intentos. Espera {m} min.',
    tab_live: 'Directo', tab_events: 'Eventos', tab_settings: 'Ajustes',
    cam_online: 'Cámara conectada', cam_offline: 'Cámara desconectada', cam_unknown: 'Cámara sin datos',
    live_connecting: 'Conectando con la cámara…', live_offline: 'La cámara no responde. Reintentando…',
    no_events: 'Todavía no hay eventos.', load_more: 'Cargar más', delete: 'Borrar', close: 'Cerrar',
    confirm_delete: '¿Borrar este evento?', clip_pending: 'El vídeo aún no ha llegado.',
    notifications: 'Notificaciones', enable_notifications: 'Activar notificaciones', send_test: 'Enviar prueba',
    push_unsupported: 'Este navegador no admite notificaciones.',
    push_insecure: 'Las notificaciones necesitan una conexión segura (HTTPS). Abre la web por la dirección de Tailscale.',
    push_blocked: 'Las notificaciones están bloqueadas en este navegador. Actívalas en los ajustes del sitio.',
    push_on: 'Notificaciones activadas en este dispositivo.', push_off: 'Notificaciones desactivadas.',
    push_error: 'No se pudieron activar las notificaciones.', push_sent: 'Prueba enviada.',
    language: 'Idioma', logout: 'Cerrar sesión',
    kind_alert: 'Movimiento detectado', kind_test: 'Prueba', kind_offline: 'Cámara desconectada',
    kind_recovered: 'Cámara reconectada', battery: 'Batería',
    alarm: 'Alarma', alarm_disarmed: 'Desarmada', alarm_exiting: 'Armando…', alarm_armed: 'Armada',
    alarm_entry: 'Movimiento detectado: esperando el PIN en el panel', alarm_unknown: 'Sin datos de la cámara',
    arm: 'Armar', disarm: 'Desarmar', alarm_error: 'La cámara no responde.',
    kind_alert_pin: 'PIN incorrecto en el panel',
    kind_battery_low: 'Batería baja', kind_power_lost: 'Sin carga (¿corte de luz?)',
    kind_power_restored: 'Vuelve a cargar', kind_hot: 'iPhone muy caliente',
    today: 'Hoy', yesterday: 'Ayer'
  },
  ca: {
    enter_pin: 'Introdueix el PIN', wrong_pin: 'PIN incorrecte', locked: 'Massa intents. Espera {m} min.',
    tab_live: 'Directe', tab_events: 'Esdeveniments', tab_settings: 'Configuració',
    cam_online: 'Càmera connectada', cam_offline: 'Càmera desconnectada', cam_unknown: 'Càmera sense dades',
    live_connecting: 'Connectant amb la càmera…', live_offline: 'La càmera no respon. Reintentant…',
    no_events: 'Encara no hi ha esdeveniments.', load_more: 'Carregar-ne més', delete: 'Esborrar', close: 'Tancar',
    confirm_delete: 'Vols esborrar este esdeveniment?', clip_pending: 'El vídeo encara no ha arribat.',
    notifications: 'Notificacions', enable_notifications: 'Activar notificacions', send_test: 'Enviar prova',
    push_unsupported: 'Este navegador no admet notificacions.',
    push_insecure: 'Les notificacions necessiten una connexió segura (HTTPS). Obri la web per l\'adreça de Tailscale.',
    push_blocked: 'Les notificacions estan bloquejades en este navegador. Activa-les als ajustos del lloc.',
    push_on: 'Notificacions activades en este dispositiu.', push_off: 'Notificacions desactivades.',
    push_error: 'No s\'han pogut activar les notificacions.', push_sent: 'Prova enviada.',
    language: 'Idioma', logout: 'Tancar la sessió',
    kind_alert: 'Moviment detectat', kind_test: 'Prova', kind_offline: 'Càmera desconnectada',
    kind_recovered: 'Càmera reconnectada', battery: 'Bateria',
    alarm: 'Alarma', alarm_disarmed: 'Desarmada', alarm_exiting: 'Armant…', alarm_armed: 'Armada',
    alarm_entry: 'Moviment detectat: esperant el PIN al panell', alarm_unknown: 'Sense dades de la càmera',
    arm: 'Armar', disarm: 'Desarmar', alarm_error: 'La càmera no respon.',
    kind_alert_pin: 'PIN incorrecte al panell',
    kind_battery_low: 'Bateria baixa', kind_power_lost: 'Sense càrrega (tall de llum?)',
    kind_power_restored: 'Torna a carregar', kind_hot: 'iPhone molt calent',
    today: 'Hui', yesterday: 'Ahir'
  },
  en: {
    enter_pin: 'Enter the PIN', wrong_pin: 'Wrong PIN', locked: 'Too many attempts. Wait {m} min.',
    tab_live: 'Live', tab_events: 'Events', tab_settings: 'Settings',
    cam_online: 'Camera online', cam_offline: 'Camera offline', cam_unknown: 'Camera: no data',
    live_connecting: 'Connecting to the camera…', live_offline: 'The camera is not responding. Retrying…',
    no_events: 'No events yet.', load_more: 'Load more', delete: 'Delete', close: 'Close',
    confirm_delete: 'Delete this event?', clip_pending: 'The video has not arrived yet.',
    notifications: 'Notifications', enable_notifications: 'Enable notifications', send_test: 'Send test',
    push_unsupported: 'This browser does not support notifications.',
    push_insecure: 'Notifications need a secure connection (HTTPS). Open the site using the Tailscale address.',
    push_blocked: 'Notifications are blocked in this browser. Enable them in the site settings.',
    push_on: 'Notifications enabled on this device.', push_off: 'Notifications are off.',
    push_error: 'Could not enable notifications.', push_sent: 'Test sent.',
    language: 'Language', logout: 'Log out',
    kind_alert: 'Motion detected', kind_test: 'Test', kind_offline: 'Camera offline',
    kind_recovered: 'Camera back online', battery: 'Battery',
    alarm: 'Alarm', alarm_disarmed: 'Disarmed', alarm_exiting: 'Arming…', alarm_armed: 'Armed',
    alarm_entry: 'Motion detected: waiting for the PIN on the panel', alarm_unknown: 'No camera data',
    arm: 'Arm', disarm: 'Disarm', alarm_error: 'The camera is not responding.',
    kind_alert_pin: 'Wrong PIN on the panel',
    kind_battery_low: 'Low battery', kind_power_lost: 'Not charging (power cut?)',
    kind_power_restored: 'Charging again', kind_hot: 'iPhone very hot',
    today: 'Today', yesterday: 'Yesterday'
  },
  de: {
    enter_pin: 'PIN eingeben', wrong_pin: 'Falsche PIN', locked: 'Zu viele Versuche. Warte {m} Min.',
    tab_live: 'Live', tab_events: 'Ereignisse', tab_settings: 'Einstellungen',
    cam_online: 'Kamera online', cam_offline: 'Kamera offline', cam_unknown: 'Kamera: keine Daten',
    live_connecting: 'Verbinde mit der Kamera…', live_offline: 'Die Kamera antwortet nicht. Neuer Versuch…',
    no_events: 'Noch keine Ereignisse.', load_more: 'Mehr laden', delete: 'Löschen', close: 'Schließen',
    confirm_delete: 'Dieses Ereignis löschen?', clip_pending: 'Das Video ist noch nicht angekommen.',
    notifications: 'Benachrichtigungen', enable_notifications: 'Benachrichtigungen aktivieren', send_test: 'Test senden',
    push_unsupported: 'Dieser Browser unterstützt keine Benachrichtigungen.',
    push_insecure: 'Benachrichtigungen brauchen eine sichere Verbindung (HTTPS). Öffne die Seite über die Tailscale-Adresse.',
    push_blocked: 'Benachrichtigungen sind in diesem Browser blockiert. Aktiviere sie in den Website-Einstellungen.',
    push_on: 'Benachrichtigungen auf diesem Gerät aktiviert.', push_off: 'Benachrichtigungen sind aus.',
    push_error: 'Benachrichtigungen konnten nicht aktiviert werden.', push_sent: 'Test gesendet.',
    language: 'Sprache', logout: 'Abmelden',
    kind_alert: 'Bewegung erkannt', kind_test: 'Test', kind_offline: 'Kamera offline',
    kind_recovered: 'Kamera wieder online', battery: 'Akku',
    alarm: 'Alarm', alarm_disarmed: 'Unscharf', alarm_exiting: 'Wird scharf…', alarm_armed: 'Scharf',
    alarm_entry: 'Bewegung erkannt: warte auf die PIN am Panel', alarm_unknown: 'Keine Kameradaten',
    arm: 'Scharf stellen', disarm: 'Unscharf stellen', alarm_error: 'Die Kamera antwortet nicht.',
    kind_alert_pin: 'Falsche PIN am Panel',
    kind_battery_low: 'Akku schwach', kind_power_lost: 'Lädt nicht (Stromausfall?)',
    kind_power_restored: 'Lädt wieder', kind_hot: 'iPhone sehr heiß',
    today: 'Heute', yesterday: 'Gestern'
  }
};
const LOCALES = { es: 'es-ES', ca: 'ca-ES', en: 'en-GB', de: 'de-DE' };

const $ = (id) => document.getElementById(id);
let lang = detectLang();
const t = (key) => (I18N[lang] && I18N[lang][key]) || I18N.es[key] || key;

function detectLang() {
  const saved = localStorage.getItem('lang');
  if (saved && I18N[saved]) return saved;
  const nav = (navigator.language || 'es').toLowerCase();
  if (nav.startsWith('ca')) return 'ca';
  if (nav.startsWith('de')) return 'de';
  if (nav.startsWith('en')) return 'en';
  return 'es';
}

function applyI18n() {
  document.documentElement.lang = lang;
  document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n); });
  $('langSelect').value = lang;
}

function formatDate(seconds) {
  return new Date(seconds * 1000).toLocaleString(LOCALES[lang] || 'es-ES', {
    day: '2-digit', month: '2-digit', year: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false
  });
}

function formatTime(seconds) {
  return new Date(seconds * 1000).toLocaleTimeString(LOCALES[lang] || 'es-ES', {
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false
  });
}

function dayKey(seconds) {
  const d = new Date(seconds * 1000);
  return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
}

function dayLabel(seconds) {
  const now = new Date();
  if (dayKey(seconds) === dayKey(now.getTime() / 1000)) return t('today');
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  if (dayKey(seconds) === dayKey(yesterday.getTime() / 1000)) return t('yesterday');
  return new Date(seconds * 1000).toLocaleDateString(LOCALES[lang] || 'es-ES', {
    day: '2-digit', month: '2-digit', year: '2-digit'
  });
}

/* ---------- Comunicación con el servidor ---------- */
async function api(path, options = {}) {
  const init = { credentials: 'same-origin', ...options };
  if (options.body) init.headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  const res = await fetch(path, init);
  if (res.status === 401 && path !== '/api/auth/login') {
    showLogin();
    throw new Error('401');
  }
  return res;
}

/* ---------- Acceso con PIN ---------- */
let pinLength = 4;
let pin = '';

async function showLogin() {
  stopLive();
  stopStatus();
  $('app').hidden = true;
  $('viewer').hidden = true;
  $('login').hidden = false;
  pin = '';
  try {
    const info = await (await fetch('/api/auth/info')).json();
    pinLength = info.pin_length || 4;
  } catch (e) { /* se usa el valor por defecto */ }
  renderDots();
  $('loginMsg').textContent = t('enter_pin');
}

function renderDots() {
  const dots = $('dots');
  dots.innerHTML = '';
  for (let i = 0; i < pinLength; i++) {
    const dot = document.createElement('span');
    if (i < pin.length) dot.className = 'on';
    dots.appendChild(dot);
  }
}

function buildPad() {
  const pad = $('pad');
  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
  keys.forEach((key) => {
    const button = document.createElement('button');
    button.textContent = key;
    if (!key) { button.style.visibility = 'hidden'; }
    button.addEventListener('click', () => pressKey(key));
    pad.appendChild(button);
  });
}

async function pressKey(key) {
  if (key === '⌫') { pin = pin.slice(0, -1); renderDots(); return; }
  if (!key || pin.length >= pinLength) return;
  pin += key;
  renderDots();
  if (pin.length < pinLength) return;

  const res = await api('/api/auth/login', { method: 'POST', body: JSON.stringify({ pin }) });
  pin = '';
  if (res.ok) { showApp(); return; }
  $('dots').classList.add('shake');
  setTimeout(() => $('dots').classList.remove('shake'), 400);
  if (res.status === 429) {
    const body = await res.json();
    const minutes = Math.ceil(((body.detail && body.detail.retry_after) || 900) / 60);
    $('loginMsg').textContent = t('locked').replace('{m}', minutes);
  } else {
    $('loginMsg').textContent = t('wrong_pin');
  }
  renderDots();
}

/* ---------- Pestañas ---------- */
let currentTab = 'live';

function showApp() {
  $('login').hidden = true;
  $('app').hidden = false;
  selectTab(currentTab);
  startStatus();
  openFromHash();
}

function selectTab(name) {
  currentTab = name;
  ['live', 'events', 'settings'].forEach((tab) => { $('tab-' + tab).hidden = tab !== name; });
  document.querySelectorAll('#nav button').forEach((b) => {
    const active = b.dataset.tab === name;
    b.classList.toggle('active', active);
    if (active) b.setAttribute('aria-current', 'page'); else b.removeAttribute('aria-current');
  });
  if (name === 'live') startLive(); else stopLive();
  if (name === 'events') { loadEvents(true); startEventsPolling(); } else { stopEventsPolling(); }
  if (name === 'settings') refreshPushState();
}

/* ---------- Directo ---------- */
let liveTimer = null;

function startLive() {
  stopLive();
  const img = $('live');
  $('liveMsg').textContent = t('live_connecting');
  img.onload = () => { $('liveMsg').textContent = ''; };
  img.onerror = () => {
    $('liveMsg').textContent = t('live_offline');
    liveTimer = setTimeout(() => { if (currentTab === 'live' && !document.hidden) startLive(); }, 5000);
  };
  img.src = '/api/camera/stream?t=' + Date.now();
}

function stopLive() {
  clearTimeout(liveTimer);
  const img = $('live');
  img.onload = null;
  img.onerror = null;
  img.removeAttribute('src');
}

document.addEventListener('visibilitychange', () => {
  if ($('app').hidden) return;
  if (document.hidden) stopLive();
  else if (currentTab === 'live') startLive();
});

/* ---------- Alarma ---------- */
let alarmState = null;
let alarmCameraOnline = false;
let alarmBusy = false;

function renderAlarm(errorText) {
  const word = $('alarmState');
  const hint = $('alarmHint');
  const button = $('alarmBtn');
  const box = $('alarm');
  if (errorText) { hint.textContent = errorText; return; }
  hint.textContent = '';
  if (!alarmCameraOnline || !alarmState) {
    box.classList.remove('armed');
    word.textContent = t('alarm_unknown');
    button.disabled = true;
    button.textContent = t('arm');
    button.className = 'btn wide primary';
    return;
  }
  // "entry" es una alarma armada que está esperando el PIN en el panel.
  word.textContent = t(alarmState === 'entry' ? 'alarm_armed' : 'alarm_' + alarmState);
  if (alarmState === 'entry') hint.textContent = t('alarm_entry');
  const armed = alarmState !== 'disarmed';
  box.classList.toggle('armed', armed);
  button.disabled = alarmBusy;
  button.textContent = armed ? t('disarm') : t('arm');
  button.className = 'btn wide ' + (armed ? 'danger' : 'primary');
}

async function toggleAlarm() {
  if (!alarmState || alarmBusy) return;
  alarmBusy = true;
  renderAlarm();
  const action = alarmState === 'disarmed' ? 'arm' : 'disarm';
  try {
    const res = await api('/api/alarm/' + action, { method: 'POST' });
    if (res.ok) {
      alarmState = (await res.json()).alarm;
      alarmBusy = false;
      renderAlarm();
    } else {
      alarmBusy = false;
      renderAlarm(t('alarm_error'));
      setTimeout(() => renderAlarm(), 3000);
    }
  } catch (e) { alarmBusy = false; }
}

/* ---------- Estado de la cámara ---------- */
let statusTimer = null;

function startStatus() {
  stopStatus();
  refreshStatus();
  statusTimer = setInterval(refreshStatus, 10000);
}

function stopStatus() { clearInterval(statusTimer); }

async function refreshStatus() {
  try {
    const res = await api('/api/status');
    const cam = (await res.json()).camera;
    const badge = $('camState');
    badge.className = 'status ' + (!cam.known ? '' : cam.online ? 'ok' : 'bad');
    badge.innerHTML = '<i></i>';
    badge.appendChild(document.createTextNode(!cam.known ? t('cam_unknown') : cam.online ? t('cam_online') : t('cam_offline')));

    // Batería y calor, sobre la imagen.
    const chips = $('liveChips');
    chips.innerHTML = '';
    if (cam.online && typeof cam.battery === 'number') {
      const chip = document.createElement('span');
      chip.textContent = Math.round(cam.battery * 100) + '%' + (cam.charging ? ' ⚡' : '');
      chips.appendChild(chip);
    }
    if (cam.online && (cam.thermal === 'serious' || cam.thermal === 'critical')) {
      const chip = document.createElement('span');
      chip.textContent = '🌡️';
      chips.appendChild(chip);
    }

    alarmCameraOnline = cam.known && cam.online;
    if (!alarmBusy) {
      alarmState = cam.alarm || (cam.armed === true ? 'armed' : cam.armed === false ? 'disarmed' : null);
      renderAlarm();
    }
  } catch (e) { /* sin datos */ }
}

/* ---------- Eventos ---------- */
function eventLabel(event) {
  if (event.kind === 'alert' && event.reason === 'pin') return t('kind_alert_pin');
  return t('kind_' + event.kind);
}

const TONES = { alert: 'bad', offline: 'warn', battery_low: 'warn', power_lost: 'warn', hot: 'warn',
  recovered: 'ok', power_restored: 'ok' };

let events = [];
let reachedEnd = false;
let lastDay = null;
let eventsTimer = null;

async function loadEvents(reset) {
  if (reset) { events = []; reachedEnd = false; lastDay = null; $('events').innerHTML = ''; }
  const before = events.length ? '&before=' + events[events.length - 1].created : '';
  const res = await api('/api/events?limit=30' + before);
  const batch = await res.json();
  if (batch.length < 30) reachedEnd = true;
  batch.forEach((event) => {
    const key = dayKey(event.created);
    if (key !== lastDay) {
      lastDay = key;
      const header = document.createElement('h3');
      header.className = 'day';
      header.textContent = dayLabel(event.created);
      $('events').appendChild(header);
    }
    events.push(event);
    $('events').appendChild(renderEvent(event));
  });
  $('noEvents').hidden = events.length > 0;
  $('more').hidden = reachedEnd || events.length === 0;
}

// Mientras se mira la lista, se comprueba si ha llegado algún evento nuevo.
function startEventsPolling() {
  stopEventsPolling();
  eventsTimer = setInterval(async () => {
    if (document.hidden || currentTab !== 'events' || !$('viewer').hidden) return;
    try {
      const res = await api('/api/events?limit=1');
      const latest = (await res.json())[0];
      if (latest && (!events.length || latest.id !== events[0].id)) loadEvents(true);
    } catch (e) { /* sin datos */ }
  }, 20000);
}

function stopEventsPolling() { clearInterval(eventsTimer); }

function renderEvent(event) {
  const button = document.createElement('button');
  button.className = 'event';
  button.dataset.id = event.id;
  let thumb;
  if (event.photo) {
    thumb = document.createElement('img');
    thumb.loading = 'lazy';
    thumb.alt = '';
    thumb.src = '/api/events/' + event.id + '/photo';
  } else {
    thumb = document.createElement('div');
    thumb.className = 'noimg';
    thumb.textContent = ({ offline: '📡', battery_low: '🔋', power_lost: '⚡', hot: '🌡️' })[event.kind] || '✔';
  }
  const text = document.createElement('div');
  const when = document.createElement('span');
  when.className = 'when';
  when.textContent = formatTime(event.created);
  const what = document.createElement('span');
  what.className = 'what';
  const dot = document.createElement('i');
  dot.className = 'dot ' + (TONES[event.kind] || '');
  what.appendChild(dot);
  what.appendChild(document.createTextNode(eventLabel(event) + (event.clip ? ' · ▶' : '')));
  text.appendChild(when);
  text.appendChild(what);
  button.appendChild(thumb);
  button.appendChild(text);
  button.addEventListener('click', () => openViewer(event));
  return button;
}

/* ---------- Visor de un evento ---------- */
let viewing = null;

let clipPoll = null;

// El clip llega unos segundos después de la foto: se comprueba hasta que aparezca.
function watchForClip(event) {
  clearInterval(clipPoll);
  if (event.clip || !event.photo || event.kind !== 'alert') return;
  const started = Date.now();
  clipPoll = setInterval(async () => {
    if (!viewing || viewing.id !== event.id || Date.now() - started > 180000) { clearInterval(clipPoll); return; }
    try {
      const res = await api('/api/events/' + event.id);
      if (!res.ok) return;
      const fresh = await res.json();
      if (fresh.clip) {
        clearInterval(clipPoll);
        viewing = fresh;
        $('viewerVideo').src = '/api/events/' + fresh.id + '/clip';
        $('viewerVideo').hidden = false;
        $('viewerNote').hidden = true;
      }
    } catch (e) { /* se reintenta */ }
  }, 5000);
}

function openViewer(event) {
  viewing = event;
  $('viewerTitle').textContent = eventLabel(event) + ' · ' + formatDate(event.created);
  const photo = $('viewerPhoto');
  photo.hidden = !event.photo;
  if (event.photo) photo.src = '/api/events/' + event.id + '/photo';
  const video = $('viewerVideo');
  const note = $('viewerNote');
  video.hidden = !event.clip;
  note.hidden = event.clip || !event.photo || event.kind !== 'alert';
  note.textContent = t('clip_pending');
  if (event.clip) video.src = '/api/events/' + event.id + '/clip'; else video.removeAttribute('src');
  $('viewer').hidden = false;
  location.hash = 'event=' + event.id;
  watchForClip(event);
}

function closeViewer() {
  clearInterval(clipPoll);
  $('viewer').hidden = true;
  $('viewerVideo').pause();
  $('viewerVideo').removeAttribute('src');
  $('viewerPhoto').removeAttribute('src');
  viewing = null;
  if (location.hash) history.replaceState(null, '', location.pathname);
}

async function deleteViewing() {
  if (!viewing || !confirm(t('confirm_delete'))) return;
  const id = viewing.id;
  await api('/api/events/' + id, { method: 'DELETE' });
  closeViewer();
  if (currentTab === 'events') loadEvents(true);
}

async function openFromHash() {
  const match = /event=([0-9a-f-]{36})/i.exec(location.hash || '');
  if (!match || $('app').hidden) return;
  try {
    const res = await api('/api/events/' + match[1]);
    if (res.ok) openViewer(await res.json());
  } catch (e) { /* evento ya borrado */ }
}
window.addEventListener('hashchange', openFromHash);

/* ---------- Notificaciones push ---------- */
function urlBase64ToUint8Array(base64) {
  const padded = (base64 + '='.repeat((4 - (base64.length % 4)) % 4)).replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(padded);
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}

async function refreshPushState() {
  const state = $('pushState');
  const enable = $('pushEnable');
  const test = $('pushTest');
  enable.hidden = true;
  test.hidden = true;
  if (!window.isSecureContext) { state.textContent = t('push_insecure'); return; }
  if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) {
    state.textContent = t('push_unsupported');
    return;
  }
  if (Notification.permission === 'denied') { state.textContent = t('push_blocked'); return; }
  const reg = await Promise.race([navigator.serviceWorker.ready, new Promise((resolve) => setTimeout(resolve, 4000))]);
  if (!reg) { state.textContent = t('push_unsupported'); return; }
  const sub = await reg.pushManager.getSubscription();
  if (sub && Notification.permission === 'granted') {
    state.textContent = t('push_on');
    test.hidden = false;
    // Se renueva el registro por si cambió el idioma o el servidor perdió la suscripción.
    api('/api/push/subscribe', { method: 'POST', body: JSON.stringify({ subscription: sub.toJSON(), lang }) });
  } else {
    state.textContent = t('push_off');
    enable.hidden = false;
  }
}

async function enablePush() {
  const state = $('pushState');
  try {
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') { await refreshPushState(); return; }
    const reg = await navigator.serviceWorker.ready;
    const key = (await (await api('/api/push/key')).json()).key;
    let sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(key)
      });
    }
    const res = await api('/api/push/subscribe', {
      method: 'POST', body: JSON.stringify({ subscription: sub.toJSON(), lang })
    });
    if (!res.ok) throw new Error('subscribe');
    await refreshPushState();
  } catch (e) {
    state.textContent = t('push_error');
  }
}

async function sendTest() {
  await api('/api/push/test', { method: 'POST' });
  $('pushState').textContent = t('push_sent');
  setTimeout(refreshPushState, 2500);
}

/* ---------- Arranque ---------- */
async function boot() {
  buildPad();
  applyI18n();
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => { /* sin HTTPS no hay service worker */ });
  }

  document.querySelectorAll('#nav button').forEach((b) => b.addEventListener('click', () => selectTab(b.dataset.tab)));
  $('more').addEventListener('click', () => loadEvents(false));
  $('viewerClose').addEventListener('click', closeViewer);
  $('viewerDelete').addEventListener('click', deleteViewing);
  $('pushEnable').addEventListener('click', enablePush);
  $('pushTest').addEventListener('click', sendTest);
  $('alarmBtn').addEventListener('click', toggleAlarm);
  $('logout').addEventListener('click', async () => {
    await fetch('/api/auth/logout', { method: 'POST', credentials: 'same-origin' });
    showLogin();
  });
  $('langSelect').addEventListener('change', (event) => {
    lang = event.target.value;
    localStorage.setItem('lang', lang);
    applyI18n();
    renderAlarm();
    refreshStatus();
    refreshPushState();
    if (currentTab === 'events') loadEvents(true);
  });

  const me = await fetch('/api/auth/me', { credentials: 'same-origin' });
  if (me.ok) showApp(); else showLogin();
}

boot();
