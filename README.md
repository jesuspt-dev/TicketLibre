# TicketLibre para iPhone · 1.0.1

Gestor de tickets **gratuito y de código abierto, con licencia MIT**. Implementación independiente en SwiftUI. No está afiliada a Ticketeca y no reutiliza su código, marca ni recursos.

**Estado real:** adaptación a **xtool 1.23.0** realizada. El manifiesto SwiftPM se ha validado y el núcleo se ha compilado realmente con Swift 6.4.1 para Linux: 8 grupos de pruebas correctos. La compilación iOS está bloqueada porque falta el SDK oficial de Apple; el intento de descargar Xcode solicita autenticación. No hay IPA ni publicación pública todavía. Las pruebas XCTest de iOS y el uso en iPhone siguen pendientes.

Lee primero [XTOOL.md](docs/XTOOL.md): incluye comandos verificados, resultados y requisitos que faltan. El workflow principal ahora compila y empaqueta con xtool sobre un runner macOS con SDK Apple. Para ejecutarlo y publicar la release desde este chat hace falta conectar GitHub.

## Empezar sin Mac

1. Lee [INSTALAR_EN_IPHONE.md](docs/INSTALAR_EN_IPHONE.md).
2. Crea un repositorio GitHub público vacío y sube el contenido de esta carpeta, incluyendo `.github`.
3. Ejecuta **Actions → Build iPhone IPA with xtool → Run workflow**, o deja que se ejecute tras el primer push a `main`.
4. Si compila y pasan las pruebas, descarga el artifact y extrae `TicketLibre-v1.0.1-iPhone-unsigned.ipa`.
5. Instálalo con AltStore Classic en tu iPhone y renuévalo antes de siete días si usas una cuenta gratuita de Apple.

No introduzcas credenciales Apple en GitHub para esta ruta. AltStore realiza la firma personal. Publicar un archivo IPA sin firma no permite instalarlo directamente desde Safari.

Para crear una descarga pública duradera del código y de la IPA sin firma, sigue la sección GitHub Releases de la guía. El workflow solo publica una release cuando se sube una etiqueta `v*` y las pruebas y la compilación pasan.

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

Hay 14 pruebas XCTest de dinero, fechas inválidas, lectura de totales, descuentos, conservación de céntimos, renombrado, archivos inválidos, copias, persistencia y duplicados. **Los XCTest de iOS están preparados, no ejecutados. Los 8 grupos portables sí se han compilado y ejecutado.** Consulta [VALIDACION.md](docs/VALIDACION.md).

## Publicación y estudio de la app de referencia

- [Investigación y decisiones](docs/INVESTIGACION.md): quejas verificadas, distinción frente al historial de correcciones y fuentes.
- [Instalación gratuita desde Windows](docs/INSTALAR_EN_IPHONE.md).
- [Publicación App Store/TestFlight](docs/PUBLICAR_APP_STORE.md): requisitos, firma y workflow opcional.
- [Privacidad](docs/PRIVACIDAD.md).
- [Licencia MIT](LICENSE) y [cambios](CHANGELOG.md).

Se puede crear el código y preparar la distribución con ChatGPT. La titularidad de las cuentas, la verificación de Apple, la firma, la aceptación de acuerdos y la revisión de App Store siguen siendo pasos externos que ChatGPT no puede omitir.
