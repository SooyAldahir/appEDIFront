// lib/tools/generic_reminders.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:edi301/tools/notification_service.dart';

// --- Definiciones de Tipos (usadas por el controlador) ---
enum RepeatIntervalUnit { DAY, WEEK, MONTH }

/// Genera un ID único basado en el hash del título y la fecha
int _generateId(String title, DateTime date) {
  return (title.hashCode + date.millisecondsSinceEpoch).abs() % 2147483647;
}

/// --- Función principal para crear el recordatorio ---
Future<void> createReminder({
  required String title,
  required String description,
  required String start_date, // "YYYY-MM-DD"
  required String end_date, // "YYYY-MM-DD"
  required String time_of_day, // "HH:MM:SS"
  required RepeatIntervalUnit repeat_interval_unit,
  required int repeat_every_n,
}) async {
  // 1. Inicializar el servicio
  final notifService = NotificationService();
  await notifService.init();

  // --- 2. PEDIR PERMISOS (LÓGICA ACTUALIZADA) ---
  // Pedir permiso básico de notificaciones
  if (await Permission.notification.isDenied) {
    if (await Permission.notification.request() != PermissionStatus.granted) {
      throw Exception('Permiso de notificaciones denegado.');
    }
  }

  // Pedir permiso especial de alarmas exactas (para Android 12+)
  if (await Permission.scheduleExactAlarm.isDenied) {
    if (await Permission.scheduleExactAlarm.request() !=
        PermissionStatus.granted) {
      // Si el usuario lo niega, no lanzamos un error,
      // pero la notificación podría no ser "exacta".
      debugPrint(
        'Permiso de alarmas exactas denegado. El recordatorio puede no ser preciso.',
      );
    }
  }
  // --- FIN DE LÓGICA DE PERMISOS ---

  // 3. Parsear entradas
  late DateTime startDate;
  late DateTime endDate;
  late List<int> timeParts;
  try {
    startDate = DateTime.parse(start_date);
    endDate = DateTime.parse(end_date);
    timeParts = time_of_day.split(':').map(int.parse).toList(); // [HH, MM, SS]
  } catch (e) {
    throw Exception('Formato de fecha/hora inválido. $e');
  }

  // 4. Bucle para programar las notificaciones
  DateTimeComponents? matchDateTimeComponents;
  if (repeat_interval_unit == RepeatIntervalUnit.DAY && repeat_every_n == 1) {
    // Repetir diariamente
    matchDateTimeComponents = DateTimeComponents.time;
  } else if (repeat_interval_unit == RepeatIntervalUnit.WEEK &&
      repeat_every_n == 1) {
    // Repetir semanalmente (mismo día de la semana y hora)
    matchDateTimeComponents = DateTimeComponents.dayOfWeekAndTime;
  }

  // 5. Programar la primera notificación
  tz.TZDateTime scheduleTime = tz.TZDateTime(
    tz.local,
    startDate.year,
    startDate.month,
    startDate.day,
    timeParts[0], // Hora
    timeParts[1], // Minuto
    timeParts[2], // Segundo
  );

  if (scheduleTime.isBefore(tz.TZDateTime.now(tz.local))) {
    if (repeat_interval_unit == RepeatIntervalUnit.DAY) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }
  }

  if (scheduleTime.isAfter(endDate)) {
    debugPrint(
      'Recordatorio omitido: La fecha de inicio ya pasó la fecha final.',
    );
    return;
  }

  final int id = _generateId(title, startDate);

  debugPrint('--- Programando Recordatorio ---');
  debugPrint('ID: $id');
  debugPrint('Título: $title');
  debugPrint('Hora Programada: $scheduleTime');
  debugPrint('Repetir: $matchDateTimeComponents');
  debugPrint('----------------------------------');

  await notifService.scheduleZonedNotification(
    id: id,
    title: title,
    body: description,
    scheduledDate: scheduleTime,
    matchDateTimeComponents: matchDateTimeComponents,
  );
}
