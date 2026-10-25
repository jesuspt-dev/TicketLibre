# IVA y totales · versión 1.0.2

La lectura de `TOTAL` solo reconocía el importe cuando estaba junto a su etiqueta. En un pie de tabla `Importe | Base | %IVA | IVA | Total`, la etiqueta estaba en la cabecera y el importe en la siguiente fila. La app descartaba las filas fiscales y proponía únicamente la suma de productos.

Caso de regresión anonimizado: productos **18,11 €**; bases **15,91 €** al tipo impreso 21 y **2,20 €** al tipo impreso 10; cuotas impresas **3,34 €** y **0,22 €**; total **21,67 €**. No se incluyen fotos, números de factura ni otros datos personales en el repositorio.

La nueva lectura reconoce las columnas, comprueba que cada base/tipo/cuota sea consistente al céntimo y suma las cuotas. Da prioridad al total impreso. Si no hay celda de total y el cuadro fiscal está completo, propone base más IVA con aviso de revisión. Una tabla incompleta o un tratamiento ambiguo mantiene un aviso, sin sumar impuestos a ciegas.

El modelo guarda IVA y su tratamiento con campos opcionales para seguir leyendo copias antiguas. Si los productos ya suman el total con IVA, no se vuelve a sumar. Los impuestos no se guardan como productos. El botón de recalcular añade el IVA solo cuando corresponde; el reparto conserva todos los céntimos, y PDF/CSV/JSON incluyen la información fiscal.

Los tickets ya guardados no se modifican automáticamente. En el editor, **IVA → Leer IVA y total del original** permite recuperar el importe desde el texto OCR que ya se guardó, sin alterar productos, imágenes o identificadores. Hay que revisar y guardar expresamente.

Pruebas nuevas: regresión de 11 productos/dos tipos de IVA, tabla sin total, IVA incluido, base explícita, subtotal ambiguo, prioridad del total impreso, resumen de IVA sin duplicación, orden de columnas, tabla incompleta, separadores de miles, nombres de productos que contienen «iva», compatibilidad de copias y conservación del reparto. El texto fiscal se prueba de forma determinista; el reconocimiento de una foto por Apple Vision y el uso real de la pantalla necesitan una prueba en iPhone tras instalar la nueva versión.
