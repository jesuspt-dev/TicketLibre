# Instalar TicketLibre gratis desde Windows + iPhone

El código es gratuito, pero un iPhone necesita una firma válida para ejecutar una app nativa. Este flujo usa firma personal de Apple mediante AltStore Classic. No es App Store ni AltStore PAL.

## 1. Obtener la IPA con GitHub

1. Crea un repositorio **público** nuevo, por ejemplo `TicketLibre`. Para el primer envío, créalo vacío, sin README ni licencia añadidos por GitHub. La licencia ya está incluida en el proyecto.
2. Extrae el ZIP. La carpeta que contiene `TicketLibre.xcodeproj`, `README.md` y `.github` es la raíz del repositorio.
3. Sube todo ese contenido, incluida `.github/workflows`. Si usas GitHub web, comprueba que `.github` aparece en el repositorio; el workflow no existe si omites esa carpeta.
4. Abre **Actions → Build iPhone IPA with xtool**. Puede que debas habilitar Actions en el repositorio. Ejecuta **Run workflow** si no se inició con el push.
5. Espera el resultado de las pruebas y la compilación. Si falla, no hay IPA válida: conserva el log del paso fallido para corregir el problema.
6. En el run correcto, descarga **TicketLibre-v1.0.1-iPhone-xtool-unsigned** desde Artifacts. Se requiere iniciar sesión en GitHub para descargar artifacts.
7. Extrae el ZIP del artifact. Dentro encontrarás la IPA y su SHA-256. **No instales el ZIP del proyecto ni el ZIP del artifact: AltStore necesita el archivo `.ipa`.**

GitHub documenta runners estándar gratuitos para repositorios públicos. Un repositorio privado tiene cuotas distintas, y el almacenamiento de artifacts tiene políticas y límites propios. Se ha fijado una retención de 7 días.

Alternativa con Git para Windows, desde PowerShell en la carpeta extraída:

```powershell
.\scripts\Publicar-GitHub.ps1 -RepositoryUrl "https://github.com/TU_USUARIO/TicketLibre.git"
```

El script comprueba el remoto y no fuerza el historial. Si usas un repositorio existente, trabaja sobre su clon y copia los archivos en él; no inicialices otro historial para reemplazarlo.

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

## 4. Publicar un enlace público de descarga de la IPA

Tras una compilación verificada, en el clon dedicado:

```powershell
git tag v1.0.1
git push origin v1.0.1
```

El workflow compila y prueba esa etiqueta y, si todo pasa, crea una GitHub Release con IPA y checksum. Los usuarios podrán descargar el archivo desde Releases. **Seguirán necesitando firmarlo con AltStore**; ese enlace no equivale a un botón de instalación App Store.

No reutilices una etiqueta existente para una build distinta. Para una actualización, incrementa versión y build en el generador de proyecto, plist, configuración, nombres de artifacts y scripts; regenera y crea otra etiqueta.

## Fallos frecuentes

- **No aparecen Actions:** revisa que subiste `.github/workflows/build-ipa.yml`.
- **Falta iOS en el runner:** el script intenta descargar la plataforma. El log mostrará si falla la instalación.
- **No hay simulador:** el test necesita un simulador iPhone en el runner macOS; instala un runtime o usa una imagen de runner que lo incluya.
- **AltStore indica formato incorrecto:** selecciona la IPA real, no uno de los ZIP contenedores.
- **Caduca o deja de abrirse:** revisa días de firma en AltStore y renueva con AltServer disponible.
- **Dice error de instalación pero la app aparece:** comprueba primero si abre, si figura en My Apps y los días de firma; no reinstales sin exportar tus datos si funciona.
- **Falla la compilación Swift:** esta entrega no ha pasado aún Xcode. El error exacto de GitHub permite corregirlo; las comprobaciones locales de estructura no lo sustituyen.

Fuentes: [cuenta gratuita Apple](https://developer.apple.com/help/account/basics/about-your-developer-account/), [AltStore Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows), [runners GitHub](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
