import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // <--- IMPORTANTE
import 'package:edi301/tools/notification_service.dart'; // <--- Tu servicio
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:edi301/src/pages/Admin/agenda/agenda_detail_page.dart';
import 'package:edi301/Login/login_page.dart';
import 'package:edi301/Register/register_page.dart';
import 'package:edi301/src/pages/Home/home_page.dart';
import 'package:edi301/src/pages/News/news_page.dart';
import 'package:edi301/src/pages/Family/familiy_page.dart';
import 'package:edi301/src/pages/Search/search_page.dart';
import 'package:edi301/src/pages/Admin/admin_page.dart';
import 'package:edi301/src/pages/Perfil/perfil_page.dart';
import 'package:edi301/src/pages/Family/Edit/edit_page.dart';
import 'package:edi301/src/pages/Admin/add_family/add_family_page.dart';
import 'package:edi301/src/pages/Admin/add_alumns/add_alumns_page.dart';
import 'package:edi301/src/pages/Admin/get_family/get_family_page.dart';
import 'package:edi301/src/pages/Admin/family_detail/Family_detail_page.dart';
import 'package:edi301/src/pages/Admin/studient_detail/studient_detail_page.dart';
import 'package:edi301/src/pages/Admin/agenda/agenda_page.dart';
import 'package:edi301/src/pages/Admin/agenda/crear_evento_page.dart';
import 'package:edi301/src/pages/Admin/reportes/reportes_page.dart';

// 1. MANEJADOR DE FONDO (Debe ir FUERA del main y de cualquier clase)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("Notificación en Background recibida: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 2. Configurar manejador de fondo
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inicializar notificaciones locales
  final notiService = NotificationService();
  await notiService.init();
  await notiService.requestPermissions(); // Pedir permiso al arrancar

  // 3. OÍDO EN PRIMER PLANO (Foreground)
  // Esto hace que vibre cuando tienes la app abierta
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Mensaje recibido en foreground: ${message.notification?.title}');

    RemoteNotification? notification = message.notification;

    if (notification != null) {
      notiService.showNotification(
        id: notification.hashCode,
        title: notification.title ?? 'Sin título',
        body: notification.body ?? '',
        payload:
            message.data['tipo'] ?? 'GENERAL', // Pasamos datos extra si hay
      );
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EDI 301',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: false,
      ),
      initialRoute: 'login',
      routes: <String, WidgetBuilder>{
        'login': (context) => const LoginPage(),
        'register': (context) => const RegisterPage(),
        'home': (context) => const HomePage(),
        'family': (context) => const FamiliyPage(),
        'edit': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          // print('🎯 Edit route recibió argumentos: $args (tipo: ${args.runtimeType})');
          final familyId = args is int ? args : 0;
          if (familyId == 0) {
            // print('⚠️ ADVERTENCIA: familyId es 0');
          }
          return EditPage(familyId: familyId);
        },
        'news': (context) => const NewsPage(),
        'search': (context) => const SearchPage(),
        'admin': (context) => const AdminPage(),
        'perfil': (context) => const PerfilPage(),
        'add_family': (context) => const AddFamilyPage(),
        'add_alumns': (context) => const AddAlumnsPage(),
        'get_family': (context) => const GetFamilyPage(),
        'family_detail': (_) => const FamilyDetailPage(),
        'student_detail': (_) => const StudentDetailPage(),
        'agenda': (context) => const AgendaPage(),
        'crear_evento': (context) => const CrearEventoPage(),
        'agenda_detail': (context) => const AgendaDetailPage(),
        'reportes': (context) => const ReportesPage(),
      },
    );
  }
}
