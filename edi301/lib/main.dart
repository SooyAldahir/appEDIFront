import 'dart:convert';
import 'dart:io';

import 'package:edi301/Login/forgot_password/forgot_password_page.dart';
import 'package:edi301/src/pages/Admin/add_tutor/add_tutor_page.dart';
import 'package:edi301/src/pages/Admin/birthdays/birthday_page.dart';
import 'package:edi301/src/pages/Notifications/notifications_page.dart';
import 'package:edi301/src/pages/Notifications/notificaciones_historial_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:edi301/tools/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/src/pages/Admin/agenda/agenda_detail_page.dart';
import 'package:edi301/Login/login_page.dart';
import 'package:edi301/Login/unlock_page.dart';
import 'package:edi301/auth/token_storage.dart';
import 'package:edi301/services/biometric_service.dart';
import 'package:edi301/Register/register_page.dart';
import 'package:edi301/src/pages/Home/home_page.dart';
import 'package:edi301/src/pages/News/news_page.dart';
import 'package:edi301/src/pages/Family/familiy_page.dart';
import 'package:edi301/src/pages/Search/search_page.dart';
import 'package:edi301/src/pages/Admin/admin_page.dart';
import 'package:edi301/src/pages/Perfil/perfil_page.dart';
import 'package:edi301/src/pages/Family/Edit/edit_page.dart';
import 'package:edi301/src/pages/Admin/add_family/add_family_page.dart';
import 'package:edi301/src/pages/Admin/add_family/add_family_manual_page.dart';
import 'package:edi301/src/pages/Admin/familias_pendientes/familias_pendientes_page.dart';
import 'package:edi301/src/pages/Admin/add_alumns/add_alumns_page.dart';
import 'package:edi301/src/pages/Admin/get_family/get_family_page.dart';
import 'package:edi301/src/pages/Admin/family_detail/Family_detail_page.dart';
import 'package:edi301/src/pages/Admin/studient_detail/studient_detail_page.dart';
import 'package:edi301/src/pages/Admin/agenda/agenda_page.dart';
import 'package:edi301/src/pages/Admin/agenda/crear_evento_page.dart';
import 'package:edi301/src/pages/Admin/reportes/reportes_page.dart';
import 'package:edi301/src/pages/Admin/assign_admin_page.dart';
import 'package:edi301/src/pages/Admin/broadcast/broadcast_page.dart';
import 'package:edi301/src/pages/Admin/renovaciones/renovaciones_admin_page.dart';
import 'package:edi301/src/pages/Admin/configuracion/limite_hijos_edi_page.dart';
import 'package:edi301/src/pages/Perfil/renovaciones/mis_renovaciones_page.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/services/socket_service.dart';
import 'package:edi301/services/users_api.dart';
import 'package:edi301/services/fcm_registro.dart';
import 'package:edi301/src/pages/Encuestas/encuestas_page.dart';
import 'package:edi301/src/pages/Admin/poblacion/poblacion_page.dart';
import 'package:edi301/services/update_service.dart';
import 'package:edi301/src/pages/Admin/version/version_app_page.dart';
import 'package:edi301/src/pages/Admin/alumnos_prueba/alumnos_prueba_page.dart';
import 'package:edi301/src/pages/Perfil/promover_cuenta/promover_cuenta_page.dart';
import 'package:edi301/services/encuestas_api.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Servicio de aviso de actualizaciones. Se crea en main().
late final UpdateService updateService;

Future<void> _openSurveyFromNotification(Map<String, dynamic> data) async {
  if (data['tipo'] != 'ENCUESTA') return;
  final id = int.tryParse('${data['id_encuesta'] ?? ''}');
  if (id == null) return;
  try {
    final survey = await EncuestasApi().get(id);
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResponderEncuestaPage(encuesta: survey),
      ),
    );
  } catch (e) {
    final context = appNavigatorKey.currentContext;
    if (context != null) Navigator.of(context).pushNamed('encuestas');
  }
}

/// Cierra la sesion local y lleva al login. La dispara ApiHttp cuando el
/// servidor responde 401 a una peticion que SI llevaba token.
///
/// Se ejecuta una sola vez aunque fallen varias peticiones a la vez: ApiHttp
/// ya tiene su propio cerrojo, y aqui ademas se comprueba que no estemos ya
/// en el login para no apilar navegaciones.
Future<void> _cerrarSesionPorTokenInvalido() async {
  try {
    SocketService().disconnect();
  } catch (_) {}

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.remove('last_fcm_token_sent');
  } catch (_) {}

  final context = appNavigatorKey.currentContext;
  if (context == null || !context.mounted) return;

  final rutaActual = ModalRoute.of(context)?.settings.name;
  if (rutaActual == 'login') return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Tu sesión se cerró. Vuelve a iniciar sesión.'),
      behavior: SnackBarBehavior.floating,
    ),
  );

  await appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
    'login',
    (_) => false,
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Notificación en Background recibida: ${message.messageId}");
}

/// Registro del token de notificaciones.
///
/// Todo lo que había aquí (esperar APNs, pedir el token, mandarlo, escuchar el
/// refresco) vive ahora en `FcmRegistro`, porque estaba duplicado en el login
/// con reglas distintas y esa diferencia era el bug: la copia del login no
/// esperaba el token de APNs.
Future<void> _syncFcmIfLoggedIn() => FcmRegistro.registrar(motivo: 'arranque');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // initSocket ahora es asíncrono: lee el session_token guardado para
  // autenticar el handshake. Si todavía no hay sesión, no conecta y se
  // levantará después del login.
  await SocketService().initSocket();

  final notiService = NotificationService();
  await notiService.init();
  notiService.onNotificationTap = (payload) {
    if (payload == null) return;
    try {
      _openSurveyFromNotification(jsonDecode(payload) as Map<String, dynamic>);
    } catch (_) {}
  };
  await notiService.requestPermissions();

  // Además del permiso del plugin local: en iOS, ESTE es el que hace que la
  // app se registre en APNs. Sin él, el token de APNs podía no llegar nunca y
  // el dispositivo se quedaba sin notificaciones.
  await FcmRegistro.pedirPermiso();

  // Se engancha sin comprobar si hay sesión: quien inicie sesión en este mismo
  // arranque también necesita la escucha, y antes se salía temprano.
  FcmRegistro.escucharRefresco();

  // Foreground: mostrar notificación local cuando la app está abierta
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print(
      '📬 Notificación foreground: ${message.notification?.title} | data: ${message.data}',
    );

    final notification = message.notification;
    if (notification != null) {
      // Usamos timestamp como ID para que cada notificación sea única
      // (hashCode puede colisionar si dos mensajes tienen el mismo texto)
      final int notifId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      notiService.showNotification(
        id: notifId,
        title: notification.title ?? 'Sin título',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    } else {
      // Mensaje "data-only" (sin notification block): construir aviso manual
      final title =
          message.data['title'] ?? message.data['titulo'] ?? 'Nuevo mensaje';
      final body = message.data['body'] ?? message.data['cuerpo'] ?? '';
      if (body.isNotEmpty) {
        final int notifId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
        notiService.showNotification(
          id: notifId,
          title: title,
          body: body,
          payload: jsonEncode(message.data),
        );
      }
    }
  });

  // El token pasó de SharedPreferences (texto plano) al almacén seguro. Esto
  // mueve el de las instalaciones anteriores; sin ello, al actualizar, todos
  // los usuarios con sesión abierta quedarían deslogueados de golpe.
  // Va ANTES de cualquier llamada autenticada.
  await TokenStorage().migrateLegacyToken();

  // ✅ Importante: sincronizar token si ya está logueado (entra directo a home)
  // El refresco ya se engancha arriba, antes del login.
  await _syncFcmIfLoggedIn();

  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('user');
  final hasSession = userJson != null && userJson.isNotEmpty;

  // Con sesión guardada y desbloqueo biométrico activo, se entra por la
  // pantalla de bloqueo en vez de ir directo a home.
  final bool bloquear =
      hasSession &&
      await BiometricService().isEnabled() &&
      await BiometricService().isAvailable();

  final String initialRoute = !hasSession
      ? 'login'
      : (bloquear ? 'unlock' : 'home');

  HttpOverrides.global = MyHttpOverrides();

  runApp(MyApp(initialRoute: initialRoute));

  // Aviso de version nueva. Va despues de runApp porque necesita un contexto
  // de navegacion para mostrar el dialogo, y se queda escuchando el ciclo de
  // vida para volver a consultar cuando la app regresa de la tienda.
  // Si falla no pasa nada: el servicio se traga cualquier error.
  updateService = UpdateService(appNavigatorKey)..iniciar();

  // Que hacer cuando el servidor rechaza la sesion (401). Pasa cuando la
  // cerraron desde otro dispositivo, cuando se alcanzo el limite de 5
  // sesiones activas y esta era la mas antigua, o si desactivaron la cuenta.
  // ApiHttp ya borro el token; aqui se limpia el resto y se manda al login.
  ApiHttp.onSesionInvalida = _cerrarSesionPorTokenInvalido;
  FirebaseMessaging.onMessageOpenedApp.listen(
    (message) => _openSurveyFromNotification(message.data),
  );
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openSurveyFromNotification(initialMessage.data),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'EDI 301',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: false,
      ),
      initialRoute: initialRoute,
      routes: <String, WidgetBuilder>{
        'login': (context) => const LoginPage(),
        'unlock': (context) => const UnlockPage(),
        'register': (context) => const RegisterPage(),
        'home': (context) => const HomePage(),
        'family': (context) => const FamiliyPage(),
        'edit': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final familyId = args is int ? args : 0;
          return EditPage(familyId: familyId);
        },
        'news': (context) => const NewsPage(),
        'search': (context) => const SearchPage(),
        'admin': (context) => const AdminPage(),
        'perfil': (context) => const PerfilPage(),
        'add_family': (context) => const AddFamilyPage(),
        'add_family_manual': (context) => const AddFamilyManualPage(),
        'familias_pendientes': (context) => const FamiliasPendientesPage(),
        'add_alumns': (context) => const AddAlumnsPage(),
        'get_family': (context) => const GetFamilyPage(),
        'family_detail': (_) => const FamilyDetailPage(),
        'student_detail': (_) => const StudentDetailPage(),
        'agenda': (context) => const AgendaPage(),
        'crear_evento': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final Map<String, dynamic>? evento = (args is Map<String, dynamic>)
              ? args
              : null;
          return CreateEventPage(eventoExistente: evento);
        },
        'agenda_detail': (context) => const AgendaDetailPage(),
        'reportes': (context) => const ReportesPage(),
        'poblacion': (context) => const PoblacionPage(),
        'version_app': (context) => const VersionAppPage(),
        'alumnos_prueba': (context) => const AlumnosPruebaPage(),
        'promover_cuenta': (context) => const PromoverCuentaPage(),
        'notifications': (_) => const NotificationsPage(),
        'notificaciones_historial': (_) => const NotificacionesHistorialPage(),
        'cumpleaños': (context) => const BirthdaysPage(),
        'add_tutor': (BuildContext context) => const AddTutorPage(),
        'forgot_password': (BuildContext context) => const ForgotPasswordPage(),
        'assign_admin': (context) => const AssignAdminPage(),
        'broadcast': (context) => const BroadcastPage(),
        'renovaciones_admin': (context) => const RenovacionesAdminPage(),
        'limite_hijos_edi': (context) => const LimiteHijosEdiPage(),
        'mis_renovaciones': (context) => const MisRenovacionesPage(),
        'encuestas': (context) => const EncuestasPage(),
      },
    );
  }
}
