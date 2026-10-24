# Instalar TicketLibre gratis desde Windows + iPhone

El código es gratuito, pero un iPhone necesita una firma válida para ejecutar una app nativa. Este flujo usa firma personal de Apple mediante AltStore Classic. No es App Store ni AltStore PAL.

## 1. Descargar la app ya compilada

1. Abre la [descarga pública de TicketLibre 1.0.1](https://github.com/jesuspt-dev/TicketLibre/releases/tag/v1.0.1).
2. En **Assets**, descarga **TicketLibre-v1.0.1-iPhone-unsigned.ipa** y guárdala en Archivos del iPhone.
3. **No necesitas crear un repositorio ni volver a compilar.** Los archivos `Source code` son el código fuente, no la app instalable.
4. La IPA publicada ha pasado 14 pruebas XCTest de iOS, 8 grupos de pruebas del núcleo y la comprobación del ejecutable arm64. Falta probar la instalación y el funcionamiento en un iPhone físico.

SHA-256: `972456fd7daed03fbc48ff8d5f976d64bf03f1385c76569ea2dbf1f9cc9a6ce7`.

Para modificar la app, crea un fork del repositorio y ejecuta **Actions → Build iPhone IPA with xtool → Run workflow**. Los artifacts de Actions requieren iniciar sesión y caducan a los 7 días; la release pública es la descarga recomendada.

## 2. Preparar AltStore Classic

1. Sigue la [guía oficial de AltStore para Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).
2. Instala los componentes iTunes/iCloud de Apple que indique esa guía para tu configuración y AltServer. No elimines Apple Mobile Device Support ni controladores necesarios.
3. Conecta el iPhone por USB, desbloquéalo y confía en el PC. Activa la sincronización Wi-Fi si quieres renovar por esa vía.
4. Desde AltServer, instala AltStore en el iPhone y completa el acceso a Apple en su propia interfaz. No compartas tu contraseña con ChatGPT ni la guardes en el repositorio.
5. En el iPhone, activa Modo de desarrollador cuando iOS lo solicite y confía en el perfil personal si aparece en Ajustes.

## 3. Instalar la IPA

1. Lleva `TicketLibre-v1.0.1-iPhone-unsigned.ipa` a Archivos del iPhone.
2. Abre **AltStore Classic → My Apps → +** y elige la IPA.
3. Espera a que AltStore la firme e instale. El archivo de GitHub está sin firma intencionadamente.
4. Abre TicketLibre, añade un ticket manual, cierra y vuelve a abrir la app para comprobar persistencia. Después prueba cámara, foto y PDF.
5. Exporta una copia de prueba antes de empezar a usarla para datos importantes.

Con cuenta gratuita los perfiles caducan a los **7 días**; renueva con AltStore/AltServer antes de ese plazo. Apple permite hasta 3 apps personales simultáneas por dispositivo; AltStore puede ocupar una de esas plazas. No es una instalación permanente sin mantenimiento.

## 4. Distribución y futuras versiones

La versión 1.0.1 ya está publicada en GitHub Releases con IPA y checksum. El código tiene licencia MIT. Este enlace distribuye el archivo y sigue requiriendo firma personal; no equivale a una instalación App Store.

Para una actualización, incrementa versión y build en el generador de proyecto, plist, configuración, nombres de artifacts y scripts; regenera el proyecto y usa una etiqueta nueva. No reutilices `v1.0.1` para publicar una versión distinta.

## Fallos frecuentes

- **No aparecen Actions:** revisa que subiste `.github/workflows/build-ipa.yml`.
- **Falta iOS en el runner:** el script intenta descargar la plataforma. El log mostrará si falla la instalación.
- **No hay simulador:** el test necesita un simulador iPhone en el runner macOS; instala un runtime o usa una imagen de runner que lo incluya.
- **AltStore indica formato incorrecto:** selecciona la IPA real, no uno de los ZIP contenedores.
- **Caduca o deja de abrirse:** revisa días de firma en AltStore y renueva con AltServer disponible.
- **Dice error de instalación pero la app aparece:** comprueba primero si abre, si figura en My Apps y los días de firma; no reinstales sin exportar tus datos si funciona.
- **Falla la compilación Swift:** la versión publicada ha pasado el workflow de iOS. Si modificas el código, conserva el error exacto de GitHub para corregirlo; las comprobaciones de estructura no sustituyen la compilación.

Fuentes: [cuenta gratuita Apple](https://developer.apple.com/help/account/basics/about-your-developer-account/), [AltStore Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows), [runners GitHub](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
