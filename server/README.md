# Servidor de PanelCasero

Hace de "cerebro" de la casa:

- controla las luces Tuya por la red local (tinytuya),
- recibe las alertas del iPhone (foto + clip de 5 s) y las guarda 30 días,
- envía notificaciones push al móvil, aunque la web esté cerrada,
- muestra el directo de la cámara y el historial en una web instalable (PWA),
- avisa si el iPhone deja de responder.

## Puesta en marcha (en el servidor)

```bash
cd ~/PanelCasero && git pull
cd server

# 1. Configuración (añade PANEL_PIN y PANEL_CAMERA_URL a tu .env; mira .env.example)
nano .env
chmod 600 .env config/devices.json

# 2. Arrancar
docker compose up -d --build
docker compose logs --tail 20
curl http://localhost:8090/health

# 3. Publicar con HTTPS dentro de tu red Tailscale (necesario para las notificaciones)
sudo tailscale serve --bg --https=443 http://localhost:8090
tailscale serve status
```

Si es la primera vez, `tailscale serve` te dará un enlace para activar HTTPS en el panel
de Tailscale. La web quedará en `https://<nombre-del-servidor>.<tu-red>.ts.net`
y **solo se puede abrir desde tus dispositivos con Tailscale**.

## En el móvil

1. Abre esa dirección en Chrome, introduce el PIN y usa el menú ⋮ → **Instalar aplicación**.
2. Ajustes → **Activar notificaciones** y acepta el permiso. Pulsa **Enviar prueba**.
3. Deja Tailscale siempre activo: las notificaciones llegan igualmente, pero para ver el
   directo o las fotos hace falta Tailscale.

## API del iPhone (cabecera `Authorization: Bearer <PANEL_TOKEN>`)

| Método | Ruta | Para qué |
|---|---|---|
| POST | `/api/device/heartbeat` | latido: `{"battery":0-1,"charging":bool,"alarm":"disarmed|exiting|armed|entry"}` |
| PUT | `/api/device/events/{uuid}` | crea el evento: `{"kind":"alert","created":epoch,"reason":"motion"|"pin"}` |
| PUT | `/api/device/events/{uuid}/photo` | sube la foto (JPEG, cuerpo directo) y avisa |
| PUT | `/api/device/events/{uuid}/clip` | sube el clip (MP4, cuerpo directo) |

El iPhone sirve además su propio directo en `http://<ip-del-iphone>:8081/stream`
(requiere la misma clave que usa el servidor); el servidor lo retransmite a la web.

## Alarma desde la web

La web (sesión con PIN) arma y desarma con `POST /api/alarm/arm` y `/api/alarm/disarm`.
El servidor se lo pide al iPhone (`POST http://<ip-del-iphone>:8081/alarm/arm`), que es quien
decide, y devuelve el estado resultante. Si el iPhone no responde, la web lo indica.

## Luces

| Método | Ruta | Cuerpo |
|---|---|---|
| GET | `/api/lights` | — |
| POST | `/api/lights/{id}/power` | `{"on": true}` |
| POST | `/api/lights/{id}/color` | `{"hue":0-360,"saturation":0-100,"brightness":1-100}` |
| POST | `/api/lights/{id}/white` | `{"brightness":1-100,"temperature":0-100}` |
| POST | `/api/lights/{id}/brightness` | `{"brightness":1-100}` |

## Seguridad

- La web pide PIN; 5 PIN erróneos bloquean el acceso 15 minutos.
- El iPhone y el servidor se autentican con `PANEL_TOKEN`.
- Las imágenes de las notificaciones usan enlaces firmados que caducan a los 30 días.
- Los datos viven en `server/data/` (ignorada por git), incluida la clave de las notificaciones.

## Avisos automáticos

Además de las alertas de la alarma, el servidor avisa por notificación cuando el iPhone:

- deja de dar señales (3 min), y cuando vuelve;
- tiene la **batería baja** (20 % por defecto, `PANEL_LOW_BATTERY_PERCENT`) y no está cargando;
- lleva más de 5 min **sin cargar** (corte de luz o cable suelto; `PANEL_POWER_LOST_MINUTES`), y cuando vuelve;
- se **calienta** (la cámara reduce su actividad sola).

## Copias de seguridad

Lo que hay que guardar para poder reconstruirlo todo: `.env`, `config/devices.json` y `data/`
(base de datos, fotos, clips y la clave de las notificaciones).

```bash
cd ~/PanelCasero/server
tar czf ~/panelcasero-copia-$(date +%F).tar.gz .env config/devices.json data
```

Para restaurar en otro servidor: clona el repositorio, descomprime ese archivo dentro de `server/`
y ejecuta `docker compose up -d --build`. Si pierdes `data/vapid_private.pem`, hay que volver a
pulsar "Activar notificaciones" en cada móvil. Guarda la copia fuera del servidor y en un sitio
privado: contiene las claves de tus luces y de la cámara.

## Pruebas

```bash
python3 -m venv venv && . venv/bin/activate
pip install -r requirements.txt pytest
python -m pytest
```
