# TicketLibre con xtool · 1.0.1 / build 2

## Estado comprobado en esta revisión

- xtool **1.23.0** oficial descargado y ejecutado en Linux x86_64.
- Swift **6.4.1** oficial instalado en el entorno de trabajo.
- `swift package dump-package` valida el manifiesto SwiftPM.
- El compilador Swift ha parseado los 18 archivos Swift (app, XCTest y pruebas portables).
- El núcleo de modelos, importes y parser **se ha compilado realmente para Linux** y ejecutado: 8 grupos de pruebas correctos, con 14.007 repartos de cantidades positivas y negativas entre 1–7 personas.
- La compilación iOS **NO ha terminado**: falta el SDK oficial Darwin/iOS. La ejecución interactiva de xtool solicita `Xcode.xip`; el script con preflight termina con código 66 y explicación explícita.
- La descarga oficial de Xcode comprobada desde este entorno devuelve la página de Apple `unauthorized`, no un XIP. No se ha accedido a ninguna cuenta Apple.
- No existe aún una IPA generada ni una release pública de TicketLibre. GitHub continúa sin conexión autenticada. Las 14 pruebas XCTest para iOS y las pruebas en iPhone siguen pendientes.

## Archivos añadidos y adaptación

`Package.swift` expone la app como biblioteca SwiftPM automática para que xtool la enlace en un ejecutable arm64 de iPhone. Usa el mismo código de la app, sin una segunda implementación.

`xtool.yml` describe el identificador, producto, plist y recursos. `scripts/prepare-xtool.py` genera un plist separado con valores literales: xtool no expande `$(EXECUTABLE_NAME)` o `$(PRODUCT_BUNDLE_IDENTIFIER)` como hace Xcode. Se conservan los plist del proyecto Xcode y se generan los de xtool a partir de ellos.

Las imágenes PNG del icono y el manifiesto de privacidad se copian a la raíz del bundle mediante la configuración de xtool. Esta ruta no depende de compilar Assets.xcassets con actool. No se utilizan colores o imágenes de catálogo con nombre desde el código SwiftUI actual.

La compilación de xtool por sí sola no confirma el registro de App Shortcuts ni la extracción de sus metadatos del sistema: deben probarse en iPhone. No se declara paridad con los metadatos de un archive de Xcode hasta verificarlo.

## Compilar en Linux o Windows mediante WSL

Instala Swift y xtool siguiendo las fuentes oficiales. La versión del compilador debe ser compatible con el SDK obtenido de Xcode. Para la versión actual, la documentación upstream indica Swift 6.4 y una descarga de Xcode 27.x; verifica el emparejamiento al elegir tu XIP.

1. Descarga `Xcode.xip` desde tu cuenta en [Apple Developer Downloads](https://developer.apple.com/download/all/?q=Xcode). Apple puede pedir acceso y aceptación de acuerdos. No es necesario instalar o ejecutar macOS para extraer ese SDK con xtool.
2. Instala el SDK:

```bash
xtool sdk install --slim /ruta/a/Xcode.xip
xtool sdk status
```

3. En la carpeta del proyecto:

```bash
bash scripts/test-core.sh
bash scripts/build-xtool.sh
```

El comando de compilación real dentro del script es:

```bash
xtool dev build --configuration release --ipa
```

No usa `--sign`, no instala automáticamente en un dispositivo y no requiere credenciales de firma para producir una IPA sin firma. Si falta el SDK, el script se detiene antes de abrir una pregunta interactiva. Si ya tienes un binario de xtool fuera del PATH, puedes indicar `XTOOL_BIN=/ruta/al/binario`.

Cuando termine correctamente, la salida será `build/TicketLibre-v1.0.1-iPhone-unsigned.ipa`. El script comprueba ZIP, ejecutable Mach-O arm64, bundle ID, versión/build, icono y manifiesto de privacidad, y genera SHA-256. Esto sigue sin sustituir una prueba de instalación.

## Compilar y publicar desde GitHub

El workflow **Build iPhone IPA with xtool** usa un runner macOS que ya dispone de herramientas y SDK de Apple. La compilación/empaquetado de la IPA se ejecuta con **xtool**, no con el sistema de build de Xcode. Los XCTest se ejecutan por separado mediante Xcode. Se fija xtool 1.23.0 y se valida el checksum del binario oficial descargado.

Al subir una etiqueta `v1.0.1`, y solo si todas las comprobaciones pasan, se publica una GitHub Release con la IPA sin firma y el checksum. Para ejecutarlo desde ChatGPT hace falta una conexión GitHub con permisos adecuados sobre el repositorio. Esa conexión no está disponible en esta entrega.

El runner macOS evita que tengas que subir el XIP de varios GB al chat. No hace falta una cuenta Apple de pago para generar la IPA sin firma. El usuario final necesita firmarla, por ejemplo con AltStore Classic. Una GitHub Release no es una publicación App Store ni instala directamente en Safari.

## Firma y App Store

xtool no elimina la firma de Apple. La instalación personal requiere la cuenta y dispositivo del titular; TestFlight/App Store requieren membresía y distribución aprobada. No se ha solicitado ni recibido una contraseña, certificado o clave privada Apple.

## Fuentes

- [xtool oficial](https://github.com/xtool-org/xtool).
- [Instalación Linux/Windows](https://github.com/xtool-org/xtool/blob/main/Documentation/xtool.docc/Installation-Linux.md).
- [Release 1.23.0](https://github.com/xtool-org/xtool/releases/tag/1.23.0).
- [Comando dev build](https://github.com/xtool-org/xtool/blob/main/Sources/XToolSupport/DevCommand.swift).
- [Esquema xtool.yml](https://github.com/xtool-org/xtool/blob/main/Sources/PackLib/PackSchema.swift).
- [Swift Ubuntu 24.04](https://www.swift.org/install/linux/ubuntu/24_04/).
