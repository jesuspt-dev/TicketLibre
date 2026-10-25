# Estado de validación · TicketLibre 1.0.2 / build 3

La corrección de IVA se incorporó mediante [PR #1](https://github.com/jesuspt-dev/TicketLibre/pull/1). El workflow ejecuta pruebas del núcleo, XCTest nativo y compilación/empaquetado con xtool. La [release v1.0.2](https://github.com/jesuspt-dev/TicketLibre/releases/tag/v1.0.2) se publicó tras pasar también [el workflow de main](https://github.com/jesuspt-dev/TicketLibre/actions/runs/40230508597). Los resultados de cada versión se distinguen de las comprobaciones de uso en un iPhone.

## Comprobaciones automáticas de 1.0.2

- Validación local Python: 16 archivos Swift de aplicación en el target, esquema XCTest, plist, privacidad, nueve iconos y coherencia de versión/build.
- `git diff --check` correcto.
- 22 grupos portables compilados y ejecutados correctamente en GitHub Actions, incluidos 14.007 repartos con restos positivos/negativos y las regresiones de [IVA](IVA.md).
- 17 XCTest ejecutados correctamente, sin fallos, y compilación/empaquetado arm64 con xtool completos en [el workflow del PR](https://github.com/jesuspt-dev/TicketLibre/actions/runs/40229722902).

Los fixtures reproducen los importes del caso comunicado sin fotos, números de factura ni otros identificadores. Verifican 18,11 € de productos + 3,56 € de IVA = 21,67 €, conservación del total impreso, IVA incluido sin duplicarlo, importes ambiguos, tablas incompletas, copias antiguas y reparto.

IPA descargada y comprobada: SHA-256 `6666adbd0a61a42a0f042ab293ddd15a675d62cf93afd057ec8379eb49531732`, ZIP íntegro, ejecutable Mach-O arm64, bundle `org.ticketlibre.ios`, versión 1.0.2/build 3 y manifiesto de privacidad. La release 1.0.1 conserva su hash anterior.

## Prueba física y límites

La versión 1.0.1/build 2 fue firmada e instalada con xtool desde Windows/WSL y una cuenta Apple gratuita el 24/10/2026. El usuario confirmó que abre y permite navegar tras confiar en el desarrollador. Este resultado no demuestra el funcionamiento físico de la nueva versión.

Pendiente para 1.0.2: actualizar encima de la app con la misma cuenta, abrir el ticket afectado, usar **IVA → Leer IVA y total del original**, revisar 3,56 € de IVA y total 21,67 €, guardar y comprobar reapertura. También hay que escanear otra vez la foto para verificar el reconocimiento real de Apple Vision: las pruebas del parser usan texto determinista.

La cobertura automática no sustituye pruebas de cámara/permisos, PDFs reales, VoiceOver, tamaños de texto, Face ID, accesos Siri, colecciones grandes, poco almacenamiento o todas las combinaciones de exportación e importación. No se afirma que todas esas funciones se hayan probado en un dispositivo.

## Reproducir

```bash
python3 scripts/validate.py
bash scripts/test-core.sh
bash scripts/test-ios.sh
bash scripts/build-xtool.sh
```

Las pruebas iOS requieren macOS y herramientas de Apple; el workflow las ejecuta por separado del build con xtool. Para firmar una IPA ya publicada desde Windows basta el entorno xtool/USB, sin instalar Xcode o el SDK en el PC. Consulta [XTOOL.md](XTOOL.md) y [INSTALAR_EN_IPHONE.md](INSTALAR_EN_IPHONE.md).
