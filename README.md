# PanelCasero

Panel de pared para un iPhone 6s reciclado: reloj, control de luces Tuya,
cámara con detección de movimiento y alarma, y previsión del tiempo.
Proyecto de código abierto bajo licencia MIT.

## Estado

- [x] Fase 0: proyecto base, pantalla horizontal/vertical, reloj, ajustes (tema e idioma) y compilación automática con GitHub Actions
- [ ] Fase 1: brillo automático
- [ ] Fase 2: luces Tuya (tocar = encender/apagar, mantener = color y brillo)
- [ ] Fase 3: cámara y detección de movimiento
- [ ] Fase 4: servidor en casa y web (PWA) con notificaciones y vídeo en directo
- [ ] Fase 5: alarma con PIN
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
```
