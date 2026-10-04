# PanelCasero

Panel de pared para un iPhone 6s reciclado: reloj, control de luces Tuya,
cámara con detección de movimiento y alarma, y previsión del tiempo.
Proyecto de código abierto bajo licencia MIT.

## Estado

- [x] Fase 0: proyecto base, pantalla horizontal/vertical, reloj, ajustes (tema e idioma) y compilación automática con GitHub Actions
- [x] Fase 1: brillo automático (mínimo / 40 % con movimiento / máximo al tocar)
- [x] Fase 2: luces Tuya (tocar = encender/apagar, mantener = color, brillo, blanco y favoritos) — servidor en `server/` y app conectada
- [x] Fase 3: cámara frontal y detección de movimiento (sensibilidad ajustable; sube el brillo al detectar movimiento)
- [x] Fase 4: servidor y web (PWA) con notificaciones y directo; la app del iPhone graba foto + clip de 5 s, los sube (con cola sin conexión), manda latidos y sirve el directo
- [x] Fase 5: alarma con PIN (candado en la cámara, 60 s de salida y de entrada, sirena tras el aviso, armar/desarmar desde la web)
- [ ] Fase 6: previsión del tiempo y pulido

## Cómo se compila

No hace falta un Mac. Cada vez que subes cambios a la rama `main`, GitHub Actions:

1. genera el proyecto de Xcode con [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de `project.yml`,
2. compila la app sin firmar para iOS 15,
3. empaqueta `PanelCasero.ipa` y lo deja como artefacto descargable en la pestaña **Actions**.

El `.ipa` sin firmar se instala en el iPhone con TrollStore.

## Estructura

```
project.yml                  Definición del proyecto (XcodeGen)
.github/workflows/build.yml  Compilación automática
PanelCasero/                 Código Swift (SwiftUI, iOS 15+)
server/                      Servidor en Docker (Python + FastAPI + tinytuya)
```
