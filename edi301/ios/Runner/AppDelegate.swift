import Flutter
import UIKit
import FirebaseMessaging
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
              GeneratedPluginRegistrant.register(with: registry)
          }

          if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
          }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ───────────────────────────────────────────────────────────────────────
  // Puente entre APNs y Firebase Messaging.
  //
  // Info.plist tiene FirebaseAppDelegateProxyEnabled = false, y con el proxy
  // apagado Firebase NO recibe el token de APNs por su cuenta: hay que
  // pasárselo a mano aquí. Faltaba, así que iOS entregaba el token a este
  // método, nadie lo reenviaba, y Messaging.apnsToken se quedaba vacío.
  //
  // Consecuencia: getAPNSToken() devolvía null, la app se salía sin registrar
  // nada, y ese dispositivo no recibía ninguna notificación. Los que sí las
  // recibían son los que tenían un token de FCM guardado de antes (la caché
  // sobrevive entre arranques), no los que estaban bien configurados; por eso
  // parecía cosa del dispositivo y no del código.
  //
  // El proxy se queda apagado a propósito: flutter_local_notifications toma
  // UNUserNotificationCenter.delegate justo arriba, y dejar que Firebase
  // también lo intercepte es pedir un conflicto.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    // Pasa en el simulador (no tiene APNs) y cuando el perfil de firma no
    // lleva el entitlement de push. Conviene que se vea en consola en vez de
    // fallar en silencio.
    NSLog("APNs: no se pudo registrar para notificaciones remotas: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
