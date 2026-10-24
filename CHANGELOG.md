# Historial

## 1.0.1 — 24/10/2026 — build 2

- Adaptación SwiftPM y configuración xtool, plist con valores literales e iconos PNG.
- xtool 1.23.0 instalado y ejecutado; intento iOS detenido por SDK Apple ausente.
- Núcleo compilado con Swift 6.4.1: 8 grupos de pruebas correctos, incluidos 14.007 repartos.
- Workflow principal cambiado para compilar y publicar IPA con xtool; sigue pendiente conectar GitHub.
- No hay IPA generada ni publicación App Store/TestFlight en esta revisión.

## 1.0.0 — 24/10/2026 — build 1

Primera implementación independiente. Código fuente preparado; la compilación Xcode, los XCTest y las pruebas en iPhone están pendientes de ejecución.

- OCR local de cámara y fotos, lectura PDF con selección de páginas y entrada de texto o manual.
- Revisión obligatoria del escaneo, edición de productos y aviso de descuadres y duplicados.
- Ámbitos Personal/Trabajo, categorías por ticket y producto, etiquetas jerárquicas, monedas separadas.
- Gráficos e informes PDF/CSV, catálogo de tiendas/productos y lista de compra con estimaciones.
- Reparto exacto en céntimos con identificadores persistentes para productos y participantes.
- Exportación por ticket JSON, ZIP, texto, imágenes optimizadas y QR propio con límite de tamaño.
- Papelera 30 días, escritura atómica, copia anterior y recuperación explícita.
- Bloqueo opcional del dispositivo, Spotlight opcional y App Shortcuts de Siri.
- Proyecto Xcode, icono, manifiesto de privacidad, XCTest y workflow para IPA sin firma.

Pendiente de paridad: widgets de estadísticas/lista, traducciones, sincronización, etiquetas automáticas y agrupación visual del listado por periodos. No importa copias propietarias de Ticketeca ni sus QR. El OCR local no tiene la misma extracción semántica que su servicio de IA.
