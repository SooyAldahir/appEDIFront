// Este archivo ya no contiene nada.
//
// Aquí vivía `OtpService`, que hablaba directamente con el servicio de
// verificación por correo desde el teléfono. Tenía dos problemas graves:
//
//   1. Las credenciales de la cuenta de servicio estaban escritas en el
//      código, así que viajaban dentro de cada APK y de cada IPA. Cualquiera
//      que descomprimiera la app las leía.
//
//   2. Comprobaba el código en el cliente. `verifyOtp` devolvía `true` ante
//      cualquier respuesta 200, incluso cuando el cuerpo decía
//      `verified: false`. Y aunque hubiera estado bien escrita, el servidor
//      nunca se enteraba de que existía un código: bastaba con llamar a la
//      API sin pasar por la app.
//
// Ahora el envío y la verificación los hace el backend, y la verificación
// ocurre en la misma petición que la acción que protege (crear la cuenta,
// cambiar la contraseña, dar de baja). Ver:
//
//   backend  src/services/otpService.js
//   app      UsersApi.enviarCodigoVerificacion
//
// IMPORTANTE: quitar el archivo no deshace la exposición. Esa contraseña
// sigue dentro de todas las apps ya instaladas y en el historial de git.
// Hay que rotarla en el servicio; una vez rotada, el valor nuevo vive solo
// en OTP_PASSWORD del servidor y no vuelve a salir de ahí.
