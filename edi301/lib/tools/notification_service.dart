// lib/tools/notification_service.dart
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      _platformDetails,
      payload: payload,
    );
  }

  Future<void> init() async {
    // 1. Inicializar Timezones
    tz.initializeTimeZones();
    // (Opcional) Configurar la zona horaria local, ej: México
    try {
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
    } catch (_) {
      // Fallback si falla
    }

    // 2. Configuración de Android
    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('ic_notification');

    // 3. Configuración de iOS
    const DarwinInitializationSettings initIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 4. Inicializar
    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initIOS,
    );

    await _notifications.initialize(
      initSettings,
      // (Opcional) Manejar toque en notificación cuando la app está cerrada/background
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // print('Notificación tocada, payload: ${response.payload}');
      },
    );
  }

  // --- Detalles del Canal de Notificación ---
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'generic_reminders', // ID del canal
        'Recordatorios', // Nombre del canal
        channelDescription: 'Recordatorios genéricos de la app',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: 'ic_notification', // Asegura que use la silueta blanca
        color: Color(0xFF13436B),
      );
  static const NotificationDetails _platformDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  // --- Función para programar la notificación ---
  Future<void> scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents, // Para repeticiones
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      _platformDetails,
      payload: payload,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  // --- Pedir permisos (importante para Android 13+ y iOS) ---
  Future<bool> requestPermissions() async {
    final plugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (plugin != null) {
      return await plugin.requestNotificationsPermission() ?? false;
    }

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }
}
