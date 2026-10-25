# TicketLibre con xtool · 1.0.2 / build 3

## Compilación e instalación

El workflow **Build iPhone IPA with xtool** usa un runner macOS con el SDK de Apple. Ejecuta pruebas portables del núcleo y XCTest nativo; compila y empaqueta la IPA con **xtool 1.23.0**, cuya descarga oficial se verifica con SHA-256. Los XCTest utilizan las herramientas de Apple por separado. No se necesitan credenciales de firma para crear una IPA sin firmar.

Los resultados y límites de prueba están en [VALIDACION.md](VALIDACION.md); los datos de la última publicación verificada están en [XTOOL_STATUS.json](XTOOL_STATUS.json). El hecho de compilar no sustituye una prueba de OCR y uso en el iPhone.

`Package.swift` expone el mismo código de la aplicación como biblioteca SwiftPM, y xtool lo enlaza en un ejecutable arm64. `xtool.yml` configura producto, identificador, plist y recursos. `scripts/prepare-xtool.py` genera un plist con valores literales porque xtool no expande las variables de Xcode. Los PNG del icono y el manifiesto de privacidad se copian al bundle; no se utiliza actool para esta ruta.

## Generar un IPA

La CI del repositorio ya prepara el SDK. Si se compila en otro entorno Linux/WSL, hay que instalar Swift, xtool y un SDK Darwin compatible siguiendo la documentación oficial. El SDK se obtiene de una descarga autorizada de Apple; no se comparte en este repositorio.

```bash
xtool sdk install --slim /ruta/a/Xcode.xip
xtool sdk status
bash scripts/test-core.sh
bash scripts/build-xtool.sh
```

El comando de build es `xtool dev build --configuration release --ipa`. Produce `build/TicketLibre-v1.0.2-iPhone-unsigned.ipa`; el script comprueba ZIP, ejecutable arm64, bundle ID, versión/build, icono y privacidad, y genera un checksum SHA-256. Si falta el SDK, termina antes de pedir datos interactivos.

En GitHub, un push a main o una etiqueta v* ejecuta el workflow. La release v1.0.2 se crea después de las pruebas y del build. Si ya existe, sus archivos se conservan; no se sobrescribe el IPA de v1.0.1 ni su hash.

## Instalar y renovar desde Windows

Para instalar una IPA publicada no hacen falta Swift ni el SDK en el PC. Se utiliza xtool dentro de WSL y una conexión con el servicio USB oficial de Apple en Windows. Consulta [la guía de instalación](INSTALAR_EN_IPHONE.md).

```bash
xtool auth login --mode password
xtool install --usb /ruta/TicketLibre-v1.0.2-iPhone-unsigned.ipa
```

El inicio de sesión se completa en una consola local interactiva: no se introducen credenciales Apple en GitHub ni en el chat. La cuenta gratuita requiere renovar la firma cada siete días. Para conservar datos, instala encima con la misma cuenta y el mismo bundle; no desinstales la app. xtool puede pedir sustituir un certificado cuando no conserva su clave privada: esa decisión debe ser explícita porque puede afectar a otras apps firmadas con él.

GitHub Releases distribuye el IPA sin firma; no es una publicación App Store/TestFlight ni instala directamente desde Safari. Esos canales requieren la cuenta y distribución correspondientes de Apple.

## Fuentes oficiales

- [xtool](https://github.com/xtool-org/xtool) y [release 1.23.0](https://github.com/xtool-org/xtool/releases/tag/1.23.0).
- [Instalación en Linux/Windows](https://github.com/xtool-org/xtool/blob/1.23.0/Documentation/xtool.docc/Installation-Linux.md).
- [Descargas de Apple](https://developer.apple.com/download/all/?q=Xcode).
