'use strict';

/* Service worker de PanelCasero: recibe las notificaciones push. */

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

// Necesario para que el navegador ofrezca instalar la web; no guarda nada en caché.
self.addEventListener('fetch', () => {});

self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) { data = {}; }
  const alert = data.kind === 'alert' || data.kind === 'offline';
  event.waitUntil(self.registration.showNotification(data.title || 'PanelCasero', {
    body: data.body || '',
    icon: '/icon-192.png',
    image: data.image || undefined,
    tag: data.tag || 'panelcasero',
    renotify: true,
    requireInteraction: alert,
    vibrate: alert ? [300, 120, 300, 120, 600] : [120],
    timestamp: data.ts ? data.ts * 1000 : Date.now(),
    data: { url: data.url || '/' }
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if ('focus' in client) {
        await client.focus();
        if ('navigate' in client) { try { await client.navigate(url); } catch (e) { /* ya está abierta */ } }
        return;
      }
    }
    await self.clients.openWindow(url);
  })());
});
