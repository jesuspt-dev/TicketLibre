# Publicar en TestFlight y App Store

## Qué se puede hacer desde ChatGPT y qué requiere tu cuenta

El proyecto y los workflows se pueden preparar aquí. La publicación normal exige que el titular se inscriba en Apple Developer Program, acepte acuerdos, complete la verificación, cree la ficha de la app y aporte la firma y credenciales de distribución. **Esta entrega no ha realizado esos pasos y no está publicada.** No existe un acceso autenticado a tu App Store Connect ni una build iOS compilada.

Apple anuncia la membresía estándar a **99 USD por año**, con precio local y fiscalidad según el país. La app puede ofrecerse a **0 €**, sin compras internas y con código MIT. Son conceptos distintos: gratuidad de la app y costes de la cuenta del editor. Determinadas entidades pueden solicitar exención; una persona que publica software libre no queda exenta automáticamente.

[Información oficial de Apple](https://developer.apple.com/programs/).

## Preparación de la cuenta

1. Inscríbete en Apple Developer Program si eliges esta ruta de pago.
2. Registra un identificador explícito propio, por ejemplo `org.tuidentidad.ticketlibre`. El valor `org.ticketlibre.ios` del proyecto es una base de desarrollo; la disponibilidad global no está verificada.
3. En App Store Connect crea una app iOS con ese Bundle ID, nombre disponible, idioma principal español y SKU propio.
4. Usa un certificado **Apple Distribution**, su clave privada y un perfil de distribución **App Store** para ese Bundle ID.
5. Crea una clave API de App Store Connect con el permiso mínimo necesario para subir builds. Conserva el Key ID, Issuer ID y la clave `.p8`.

No se necesita App Groups, iCloud, push ni backend para esta versión. El proyecto no incluye widgets que requieran perfiles adicionales.

## Obtener el certificado desde Windows

No necesitas poseer un Mac para crear una solicitud de certificado. En un equipo con OpenSSL:

```bash
openssl req -new -newkey rsa:2048 -nodes -keyout distribution.key -out CertificateSigningRequest.certSigningRequest -subj "/CN=TicketLibre Distribution"
```

Sube el CSR en la sección de certificados de Apple Developer para crear Apple Distribution. Descarga el certificado `.cer` y combina certificado y clave privada en un `.p12` protegido con contraseña:

```bash
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -inkey distribution.key -in distribution.pem -out distribution.p12
```

Guarda la clave privada en un lugar privado. No la subas al repositorio ni la pegues en un chat. Instalar OpenSSL es un requisito adicional si aún no lo tienes. En Apple Developer genera después el perfil App Store para el identificador y certificado elegidos.

## Workflow opcional ya preparado

`.github/workflows/testflight.yml` solo se ejecuta manualmente. Usa un entorno GitHub llamado `app-store`, prueba la app, importa el certificado en un llavero temporal, valida el perfil, firma, exporta la IPA y la valida/sube a App Store Connect. El script intenta limpiar los materiales temporales al terminar. No crea la ficha de la app ni aprueba la beta automáticamente.

En **Settings → Environments → app-store → Secrets** del repositorio añade:

| Secret | Contenido |
|---|---|
| `APPLE_TEAM_ID` | Identificador del equipo de Apple |
| `APP_BUNDLE_ID` | Identificador explícito usado en Apple y en la ficha |
| `P12_BASE64` | Bytes de `distribution.p12` codificados en Base64, sin saltos |
| `P12_PASSWORD` | Contraseña del P12 |
| `PROFILE_BASE64` | Perfil App Store `.mobileprovision` en Base64 |
| `ASC_KEY_ID` | Key ID de la API App Store Connect |
| `ASC_ISSUER_ID` | Issuer ID de la misma cuenta |
| `ASC_KEY_P8_BASE64` | Clave privada `.p8` en Base64 |

Para codificar un archivo local en PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\distribution.p12"))
```

Pon ese resultado en el secret correspondiente, no en un commit. No compartas el resultado en el chat. Repite para los otros dos archivos.

En **Actions → Optional - Upload to TestFlight → Run workflow**, introduce un número de build nuevo. La versión comercial de esta entrega es `1.0.1`. Un número de build ya procesado por Apple no puede volver a usarse para otra subida de la misma versión.

El workflow de firma también está pendiente de ejecución real: debe ajustarse si Apple o el runner cambian sus herramientas o si la cuenta requiere otra configuración. No se puede garantizar su éxito sin certificados, perfil y cuenta válidos.

## TestFlight

Tras el procesamiento de Apple, en App Store Connect:

1. Completa los datos de la beta y contacto de revisión.
2. Crea el grupo de pruebas y añade la build.
3. Para testers externos, presenta la primera beta a revisión y activa el enlace público cuando Apple la apruebe.
4. Comparte el enlace generado por Apple. No inventes un enlace de TestFlight antes de que exista.

Las builds duran hasta **90 días** desde la subida. TestFlight permite probar sin AltServer ni renovación semanal en el PC, pero no es distribución permanente. [Documentación oficial](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

## App Store

Tras pruebas satisfactorias en iPhone:

- Elige precio **gratis** y no configures compras internas ni suscripciones.
- Prepara capturas reales de la build, descripción, palabras clave, soporte y URL de privacidad accesible públicamente. El archivo `PRIVACIDAD.md` incluye un borrador; la información de contacto y su publicación dependen del titular.
- Completa categoría, edad, disponibilidad territorial y privacidad. Según el código actual no hay recopilación propia de datos; revisa la declaración si añades servicios o SDKs.
- Indica en notas de revisión que el OCR funciona localmente y no hay cuenta de usuario ni pagos. La prueba del escáner requiere un dispositivo compatible con cámara.
- Selecciona la build, completa las preguntas de cumplimiento de Apple, presenta a revisión y elige cómo liberarla al ser aprobada.

No uses Ticketeca en el nombre, icono o material que sugiera que se trata de la misma app. La norma 4.1 de Apple aborda las copias; nombre/diseño propios y funcionalidad útil no garantizan por sí solos la aprobación. [Reglas de revisión](https://developer.apple.com/app-store/review/guidelines/).

[Subir builds a Apple](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/) · [Distribuir para pruebas y publicación](https://developer.apple.com/documentation/Xcode/distributing-your-app-for-beta-testing-and-releases).
