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
| POST | `/api/device/heartbeat` | latido: `{"battery":0-1,"charging":bool,"armed":bool}` |
| PUT | `/api/device/events/{uuid}` | crea el evento: `{"kind":"alert","created":epoch}` |
| PUT | `/api/device/events/{uuid}/photo` | sube la foto (JPEG, cuerpo directo) y avisa |
| PUT | `/api/device/events/{uuid}/clip` | sube el clip (MP4, cuerpo directo) |

El iPhone sirve además su propio directo en `http://<ip-del-iphone>:8081/stream`
(requiere la misma clave que usa el servidor); el servidor lo retransmite a la web.

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

## Pruebas

```bash
python3 -m venv venv && . venv/bin/activate
pip install -r requirements.txt pytest
python -m pytest
```
