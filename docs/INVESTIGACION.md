# Investigación: Ticketeca y distribución iPhone con ChatGPT

Consulta: 24 de octubre de 2026. Fuentes públicas, principalmente Apple y documentación de los proveedores.

## Conclusión práctica

ChatGPT puede generar el proyecto, código, pruebas y automatización de compilación. Para instalar una app nativa sigue haciendo falta compilar con herramientas Apple y firmarla. No necesitas tener un Mac si la compilación se ejecuta en un runner macOS de GitHub; sí necesitas completar las acciones de cuenta y firma. No hay una publicación App Store gratuita y permanente para cualquier desarrollador individual por el hecho de crear el código con ChatGPT.

| Ruta | Coste y requisito del editor | Instalación | Duración/limitación |
|---|---|---|---|
| GitHub + AltStore Classic | Cuenta GitHub y cuenta Apple gratuitas; usar runners estándar en repositorio público | IPA descargable que AltStore firma en tu iPhone, con apoyo de Windows/AltServer | La firma gratuita caduca normalmente a los 7 días; hay límites de Apple para apps y dispositivos |
| TestFlight | Apple Developer Program, anunciado a 99 USD/año o equivalente local | Enlace de invitación que instala desde TestFlight | Cada build dura hasta 90 días; las betas externas requieren revisión inicial |
| App Store | Apple Developer Program y revisión de Apple | Descarga normal desde App Store, que puede ser gratis | Publicación y mantenimiento sujetos a Apple; la membresía no es un pago del usuario por escaneo |
| Web app/PWA | Puede alojarse sin coste según plataforma y cuotas | Añadir a pantalla de inicio desde Safari | Es otra implementación y no dispone de todas las mismas APIs nativas |

Apple contempla exenciones de cuota para ciertas entidades elegibles; que el código sea abierto no concede automáticamente una exención individual. Tampoco se debe confundir la distribución web de una PWA con instalar una IPA nativa desde una URL: la distribución web nativa en la UE exige elegibilidad y autorización específicas.

Fuentes: [Apple Developer Program](https://developer.apple.com/programs/), [límites de cuenta gratuita](https://developer.apple.com/help/account/basics/about-your-developer-account/), [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), [AltStore Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows), [GitHub Actions](https://docs.github.com/en/actions/concepts/billing-and-usage), [distribución web UE](https://developer.apple.com/support/web-distribution-eu/).

## Evidencia pública sobre Ticketeca

Se identificó la app **Gestión de tickets: Ticketeca**, de Taps and Swipes, ID Apple `6474066806`; en otros países figura como Receipteka. La ficha española recuperada muestra 8 valoraciones y solo unas pocas reseñas con texto. La muestra es pequeña: no representa a todos los usuarios ni permite certificar una búsqueda exhaustiva de todas las quejas. La ficha británica consultada no muestra suficientes valoraciones para un resumen.

| Evidencia | Fecha | Respuesta en TicketLibre |
|---|---|---|
| Una reseña considera caro pagar por escaneos | 15/05/2025 | OCR local, sin compra de créditos ni suscripciones |
| Otra pide separar tickets personales y de trabajo para generar informes | 26/12/2024 | Campo Personal/Trabajo y filtro en informes y consultas |

El desarrollador respondió a la observación de precio indicando que había añadido opciones más económicas. Estas reseñas no prueban que la app actual tenga defectos de funcionamiento.

El historial público menciona correcciones de fecha, conexión, renombrado de participantes y actualización de asignaciones tras editar productos. Son **fallos históricos que el desarrollador declara corregidos**, no quejas nuevas ni pruebas de que sigan ocurriendo. Aquí se abordan con validación de fechas, funcionamiento local, identidades persistentes y pruebas específicas. Esto describe decisiones implementadas; la ausencia de fallos debe verificarse en dispositivos.

Fuentes: [reseñas españolas](https://apps.apple.com/es/app/gesti%C3%B3n-de-tickets-ticketeca/id6474066806?platform=ipad&see-all=reviews), [ficha española](https://apps.apple.com/es/app/gesti%C3%B3n-de-tickets-ticketeca/id6474066806?platform=ipad), [historial internacional](https://apps.apple.com/us/app/receipts-manager-receipteka/id6474066806?platform=mac), [ficha británica](https://apps.apple.com/gb/app/receipts-manager-receipteka/id6474066806?platform=ipad). Las versiones y fechas visibles pueden variar entre fichas y cachés regionales.

## Decisiones de implementación

TicketLibre persigue una alternativa funcional, no una reproducción exacta. La norma 4.1 de Apple contempla rechazar copias y el uso no autorizado de nombre, marca o icono de otro desarrollador. Se utilizan nombre, icono, interfaz y código propios. Tampoco se promete aprobación de Apple. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

Para eliminar costes recurrentes de inferencia se emplea Apple Vision en el dispositivo. Es una decisión técnica: el reconocimiento visual y las reglas de extracción tienen limitaciones frente al razonamiento de un modelo remoto. Siempre se ofrece revisión antes de guardar, y la fecha o el total no reconocidos generan un aviso. [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest).

Se usa aritmética entera para gastos/repartos y valores decimales al interpretar cantidades; los cálculos no dependen de coma flotante binaria. Los gráficos convierten a Double solo para dibujar. Las monedas nunca se combinan en un total. El reparto conserva el total exacto, incluidos descuentos y céntimos sobrantes.

La copia automática anterior y la escritura atómica reducen riesgos al guardar. La recuperación de una colección corrupta es explícita: no se sustituye silenciosamente por una colección vacía. Las copias externas siguen siendo necesarias.

## Pendiente de equivalencia y publicación

Esta entrega no incluye todos los comportamientos de la referencia: faltan widgets, sincronización, traducciones, etiquetado automático, agrupaciones visuales de tickets y fusión asistida de productos. No se ha instalado la app de referencia ni comparado cada interacción en un iPhone. La interfaz de TicketLibre no es idéntica.

El resultado actual es código fuente con proyecto y automatización. Falta ejecutar la compilación Xcode y pruebas nativas, comprobar cámara/OCR con tickets reales, instalar una build y publicar desde una cuenta del titular. No hay todavía una URL de descarga de una app nativa firmada. El ZIP de esta entrega es el proyecto, no una IPA.
