# Instalar o actualizar TicketLibre desde Windows con xtool

La app es gratuita y necesita una firma Apple personal para abrirse en el iPhone. No se instala desde Safari con un clic ni es una publicación App Store/TestFlight. Puedes usar tu cuenta gratuita y renovar antes de siete días; introduce contraseña y código únicamente en tu consola local, nunca en GitHub.

## Descargar la versión corregida

La corrección de IVA es **1.0.2/build 3**. Cuando la compilación y las pruebas terminen correctamente, estará en [GitHub Releases](https://github.com/jesuspt-dev/TicketLibre/releases/tag/v1.0.2):

- `TicketLibre-v1.0.2-iPhone-unsigned.ipa`
- `TicketLibre-v1.0.2-iPhone-unsigned.ipa.sha256`

Comprueba el IPA contra el SHA-256 publicado. El archivo Source code no es la app. La release 1.0.1 y su archivo anterior se conservan; no contienen esta corrección.

## Preparar la conexión

1. Sigue la [guía oficial de xtool para Linux/Windows](https://github.com/xtool-org/xtool/blob/1.23.0/Documentation/xtool.docc/Installation-Linux.md) para WSL2 y xtool. Para instalar esta IPA ya compilada no necesitas Swift, el SDK de Xcode ni compilar el proyecto.
2. Instala zip, unzip y las herramientas libimobiledevice en Ubuntu. Conecta el iPhone por USB, desbloquéalo y acepta Confiar.
3. Si USB/IP se atasca con errores muxError o paquetes demasiado grandes, usa el [puente al servicio USB oficial de Apple en Windows documentado por xtool](https://github.com/xtool-org/xtool/issues/19#issuecomment-2898986718). Este fue el método que permitió la instalación física verificada de 1.0.1. Usa reglas de red limitadas al entorno WSL y retira el puente temporal al terminar; conserva configuraciones anteriores.

## Firmar e instalar

En la consola local de Ubuntu, dentro de la carpeta del IPA:

```bash
xtool auth login --mode password
xtool install --usb TicketLibre-v1.0.2-iPhone-unsigned.ipa
```

Si xtool pide revocar un certificado existente, revisa el aviso y decide expresamente: puede afectar a otras apps firmadas con él. No se deben aceptar revocaciones automáticamente.

Si iOS solicita Modo desarrollador, actívalo en Ajustes → Privacidad y seguridad y completa el reinicio/confirmación. Si pide confiar en el desarrollador, entra en Ajustes → General → VPN y gestión de dispositivos → tu cuenta → Confiar.

## Actualizar sin perder los tickets

Usa la **misma cuenta Apple** con la que instalaste TicketLibre y vuelve a instalar encima. No desinstales la app. Puedes exportar una copia JSON antes de actualizar. El identificador base org.ticketlibre.ios se conserva; xtool lo adapta a tu equipo Apple como antes.

Para el ticket que se guardó sin IVA: ábrelo y pulsa **IVA → Leer IVA y total del original**. Comprueba **18,11 € de productos + 3,56 € de IVA = 21,67 €** y guarda. Los tickets anteriores no se cambian automáticamente.

Con una cuenta gratuita, renueva la firma antes de que se cumplan siete días con la misma cuenta y reinstalando encima. Retira al terminar las credenciales/temporales creados durante tu sesión; conserva los componentes necesarios para la siguiente renovación. Los instaladores de terceros o scripts que tengan fijada la URL/hash de 1.0.1 deben actualizarse a la nueva release para obtener la corrección.