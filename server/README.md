# Servidor de PanelCasero

Puente entre el iPhone y las luces Tuya. Habla con las luces por la red local
(tinytuya), mantiene su estado actualizado y ofrece una API protegida con una
clave secreta.

## Puesta en marcha (en el servidor)

```bash
git clone https://github.com/Ryu-DIL/PanelCasero.git ~/PanelCasero
cd ~/PanelCasero/server

cp .env.example .env
nano .env                      # pon PANEL_TOKEN=$(openssl rand -hex 24)

cp config/devices.example.json config/devices.json
nano config/devices.json       # pon id, ip, local_key y version de cada luz

docker compose up -d --build
curl http://localhost:8090/health
```

Los archivos `.env` y `config/devices.json` están en `.gitignore`: contienen
secretos y no deben subirse nunca al repositorio.

## API (todas con cabecera `Authorization: Bearer <PANEL_TOKEN>`)

| Método | Ruta | Cuerpo |
|---|---|---|
| GET | `/api/lights` | — |
| POST | `/api/lights/{id}/power` | `{"on": true}` |
| POST | `/api/lights/{id}/color` | `{"hue":0-360,"saturation":0-100,"brightness":1-100}` |
| POST | `/api/lights/{id}/white` | `{"brightness":1-100,"temperature":0-100}` (400 si la luz no tiene modo blanco) |
| POST | `/api/lights/{id}/brightness` | `{"brightness":1-100}` |

## Pruebas

```bash
python3 -m venv venv && . venv/bin/activate
pip install -r requirements.txt httpx pytest
python -m pytest
```
