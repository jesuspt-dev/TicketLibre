# Estado de validación · TicketLibre 1.0.1

## Realizado en el entorno de creación

- Generación y lectura del proyecto PBX con un parser independiente, con targets TicketLibre y TicketLibreTests.
- Verificación de que todos los archivos Swift de la app aparecen en el target y existe el esquema compartido con XCTest.
- Parseo real con swiftc de los 18 archivos Swift y validación SwiftPM. Compilación y ejecución del núcleo en Linux con 8 grupos de pruebas correctos; esto no verifica la interfaz ni los frameworks de iOS.
- Validación de los plist de aplicación/privacidad y coherencia de versión/build.
- Comprobación de las nueve imágenes AppIcon, sus dimensiones, referencias y ausencia de canal alfa. Inspección visual del icono de 1024 px.
- Comprobación estructural de workflows YAML y sintaxis Bash de scripts.
- Verificación de integridad del ZIP final y exclusión de historial Git, credenciales y resultados de compilación.

## Preparado pero NO ejecutado aquí

- 14 métodos XCTest, incluidos miles de combinaciones de reparto con distintos restos positivos y negativos.
- Compilación de todos los Swift con el compilador de Apple.
- Build para iPhone físico, empaquetado IPA, firma de AltStore y arranque en un iPhone.
- Workflow opcional de firma/subida a TestFlight y revisión de Apple.
- Pruebas visuales de pantallas reales, cámara, permisos, PDFs, accesibilidad y bloqueo en un dispositivo.

Este entorno dispone ahora de Swift 6.4.1 y xtool 1.23.0 en Linux; no dispone del SDK Darwin/iOS. La comprobación de estructura y el parseo de sintaxis **no demuestra que el proyecto compile ni sustituye un test de uso**. No se debe distribuir como una aplicación ya probada hasta completar la siguiente lista.

## Verificación nativa necesaria antes de la primera publicación

1. CI completa en verde, con XCTest y build iPhoneOS; descargar la IPA real y verificar su checksum.
2. Instalar con AltStore, abrir, añadir ticket, cerrar y reabrir y comprobar datos.
3. Escanear tickets de al menos tres tiendas; probar descuentos, IVA, productos por peso, ticket largo y fecha ilegible. Comparar el total con el papel.
4. Importar foto girada y PDF con y sin capa de texto. Probar selección de páginas y un PDF protegido.
5. Probar un descuadre y un duplicado y verificar que la decisión sigue siendo explícita.
6. Separar Personal/Trabajo y EUR/USD/GBP; exportar y abrir PDF/CSV con la selección correcta.
7. Dividir 10,01 € entre tres personas y asignar descuentos; verificar suma, renombrado de personas/productos y reapertura.
8. Exportar copia, importar nuevos registros sin reemplazar los existentes y probar recuperación con datos de prueba.
9. Mover a papelera, restaurar y eliminar definitivamente. Verificar el comportamiento a los 30 días con una build de pruebas y reloj controlado.
10. Probar lista de compra y estimación, QR pequeño, rechazo de QR grande, JSON y ZIP abriéndolo con otra aplicación.
11. Activar bloqueo; probar segundo plano con un editor, escáner y hoja de compartir abiertos; comprobar que se pide autenticación al volver. Probar cancelación, código y Siri desde app cerrada.
12. Probar iPhone pequeño, tamaños de texto grandes, modo oscuro/claro, VoiceOver y contraste. No se han generado capturas de interfaz simulando que proceden de Xcode.
13. Probar una colección grande y espacio insuficiente; exportar antes y confirmar que un error de escritura no sustituye la colección por datos vacíos.

## Alcance de las correcciones

El código evita el cobro por escaneos y añade la separación Personal/Trabajo solicitada en las reseñas encontradas. Las medidas de robustez abordan clases de errores del historial público. Sin pruebas nativas ejecutadas, no se puede afirmar que todos esos errores estén corregidos ni que no existan otros.

El bloqueo exacto y los resultados de las pruebas portables están documentados en [XTOOL.md](XTOOL.md).
