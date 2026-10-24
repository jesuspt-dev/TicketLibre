# TicketLibre para iPhone · 1.0.1

Gestor de tickets **gratuito y de código abierto, con licencia MIT**. Implementación independiente en SwiftUI. No está afiliada a Ticketeca y no reutiliza su código, marca ni recursos.

**Estado real (24/10/2026):** código publicado y primera IPA generada con **xtool 1.23.0**, usando el SDK iOS 26.5 de Xcode 26.6 en GitHub Actions. Han pasado **14 pruebas XCTest nativas y 8 grupos de pruebas del núcleo**. El paquete se ha comprobado como archivo IPA válido con ejecutable arm64, versión, icono y manifiesto de privacidad. La instalación y el uso en un iPhone físico siguen pendientes.

**[Descargar TicketLibre 1.0.1](https://github.com/jesuspt-dev/TicketLibre/releases/tag/v1.0.1)** · [Compilación y pruebas verificadas](https://github.com/jesuspt-dev/TicketLibre/actions/runs/40117314673).

La IPA está **sin firmar**: necesita firma personal e instalación con AltStore Classic. No se instala directamente desde Safari. La app y el código son gratuitos; esta publicación es una descarga de GitHub, no una publicación en App Store/TestFlight.

## Empezar sin Mac

1. Lee [INSTALAR_EN_IPHONE.md](docs/INSTALAR_EN_IPHONE.md).
2. Descarga la IPA desde la release. Para modificar y recompilar el proyecto, crea un fork de este repositorio.
3. Ejecuta **Actions → Build iPhone IPA with xtool → Run workflow**, o deja que se ejecute tras el primer push a `main`.
4. Si compila y pasan las pruebas, descarga el artifact y extrae `TicketLibre-v1.0.1-iPhone-unsigned.ipa`.
5. Instálalo con AltStore Classic en tu iPhone y renuévalo antes de siete días si usas una cuenta gratuita de Apple.

No introduzcas credenciales Apple en GitHub para esta ruta. AltStore realiza la firma personal. Publicar un archivo IPA sin firma no permite instalarlo directamente desde Safari.

Para crear una descarga pública duradera del código y de la IPA sin firma, sigue la sección GitHub Releases de la guía. El workflow publica la release tras pasar las pruebas y la compilación en `main` o en una etiqueta `v*`.

## Funciones implementadas en el código

- Escaneo multipágina con cámara y OCR local de Apple Vision, sin tokens ni servicios de pago.
- Importación de fotos, PDF con selección de páginas, texto UTF-8, portapapeles mediante acción explícita y entrada manual.
- Revisión antes de guardar, edición de fecha, tienda, productos, cantidades, descuentos y total.
- Avisos de descuadre y posibles duplicados sin fusionarlos automáticamente.
- Separación Personal/Trabajo, categorías por ticket y producto, etiquetas con rutas `hogar/cocina` y búsqueda.
- Gráficos diarios/categorías y periodos semana, mes, trimestre, año o intervalo personalizado.
- Monedas EUR/USD/GBP analizadas por separado, sin sumas de monedas distintas ni conversiones inventadas.
- Historial por tienda/producto/etiqueta; lista de compra con precio orientativo a partir del historial.
- Reparto por producto entre participantes, descuentos y ajuste global, conservando todos los céntimos.
- Exportación PDF/CSV, copia JSON, ZIP por ticket, texto, imágenes optimizadas y QR de TicketLibre para tickets pequeños.
- Papelera 30 días, copia local anterior, recuperación explícita e importación validada de copias.
- Modo claro/oscuro, accesibilidad nativa de formularios, bloqueo opcional con Face ID/código, Spotlight opcional y App Shortcuts de Siri.
- Apariencia nativa en iOS 18+ y efecto Liquid Glass explícito en la acción principal en iOS 26+.

## Lo que aún no equivale a Ticketeca

Esta versión **no es un clon exacto ni tiene paridad completa**. No incluye widgets, sincronización entre dispositivos, todas sus traducciones, etiquetas automáticas, agrupación visual de la lista por semana/año, fusión de productos ni importación de sus formatos propietarios. Los gráficos sí permiten los periodos indicados. Los nombres de productos se agrupan ignorando mayúsculas y acentos, sin sustituir productos parecidos mediante IA.

El OCR local reconoce texto y propone campos con reglas. **No tiene la misma capacidad de interpretación que un servicio de IA remoto.** En tickets complejos puede equivocarse con columnas, precios por peso, subtotales o descuentos. La revisión humana está incluida por este motivo. No se promete que todos los fallos posibles estén resueltos ni se atribuyen a reseñas problemas que no se hayan documentado.

Las imágenes se optimizan a un máximo de 1800 píxeles y JPEG: son copias visuales del escaneo, no los bytes originales de los archivos importados. Conserva el documento original si necesitas su fidelidad exacta. Un QR omite fotografías, texto OCR y notas para caber; usa JSON/ZIP para compartir el registro completo. Los QR de Ticketeca no son compatibles.

## Privacidad y límites

No hay red en el código de la app, backend, analítica, anuncios ni cuentas. El sistema puede incluir los datos locales en las copias del dispositivo según tus ajustes. Exportar un archivo o compartirlo sale del almacenamiento privado de la app: las copias JSON/ZIP no están cifradas.

La colección admite hasta 20.000 tickets y 250 MB codificados; cada ticket hasta 20 imágenes optimizadas. La importación de PDF/foto desde Archivos admite 40 MB. Son límites técnicos de esta versión, no cuotas de pago. La escritura JSON atómica protege frente a cambios incompletos y conserva la versión anterior. En colecciones grandes puede consumir memoria y tardar; una base SQLite con adjuntos independientes sería la evolución indicada antes de distribuir a gran escala.

El bloqueo reduce la exposición de la interfaz y protege las presentaciones propias. No sustituye el cifrado individual de copias exportadas. El selector de Archivos, la hoja de compartir y las copias del dispositivo son servicios del sistema.

## Proyecto y comprobaciones

Abre `TicketLibre.xcodeproj`, esquema compartido `TicketLibre`. No requiere dependencias Swift externas. Compila con Xcode 26 o posterior y SDK iOS; deployment target iOS 18. App orientada a iPhone.

```bash
python3 scripts/validate.py
bash scripts/test-ios.sh
bash scripts/build-xtool.sh
```

`validate.py` solo valida estructura, iconos, plist y configuración; no compila la interfaz iOS. Las pruebas XCTest requieren macOS/Xcode; el build con xtool funciona en Linux con SDK Darwin instalado o en macOS con el SDK de Xcode. El workflow selecciona Xcode adecuado, comprueba la plataforma iOS, ejecuta XCTest y crea el paquete `Payload/TicketLibre.app`. No usa tuberías que corten la salida de `xcodebuild` con `head`.

Hay 14 pruebas XCTest de dinero, fechas inválidas, lectura de totales, descuentos, conservación de céntimos, renombrado, archivos inválidos, copias, persistencia y duplicados. **Los 14 XCTest de iOS y los 8 grupos portables se han ejecutado correctamente en GitHub Actions.** Consulta [VALIDACION.md](docs/VALIDACION.md).

## Publicación y estudio de la app de referencia

- [Investigación y decisiones](docs/INVESTIGACION.md): quejas verificadas, distinción frente al historial de correcciones y fuentes.
- [Instalación gratuita desde Windows](docs/INSTALAR_EN_IPHONE.md).
- [Publicación App Store/TestFlight](docs/PUBLICAR_APP_STORE.md): requisitos, firma y plantilla opcional en `docs/testflight-workflow.yml`.
- [Privacidad](docs/PRIVACIDAD.md).
- [Licencia MIT](LICENSE) y [cambios](CHANGELOG.md).

Se puede crear el código y preparar la distribución con ChatGPT. La titularidad de las cuentas, la verificación de Apple, la firma, la aceptación de acuerdos y la revisión de App Store siguen siendo pasos externos que ChatGPT no puede omitir.
