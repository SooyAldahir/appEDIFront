// lib/tools/generic_reminders.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:edi301/tools/notification_service.dart';

enum RepeatIntervalUnit { DAY, WEEK, MONTH }

int _generateId(String title, DateTime date) {
  return (title.hashCode + date.millisecondsSinceEpoch).abs() % 2147483647;
}

Future<void> createReminder({
  required String title,
  required String description,
  required String start_date,
  required String end_date,
  required String time_of_day,
  required RepeatIntervalUnit repeat_interval_unit,
  required int repeat_every_n,
}) async {
  final notifService = NotificationService();
  await notifService.init();

  if (await Permission.notification.isDenied) {
    if (await Permission.notification.request() != PermissionStatus.granted) {
      throw Exception('Permiso de notificaciones denegado.');
    }
  }

  if (await Permission.scheduleExactAlarm.isDenied) {
    if (await Permission.scheduleExactAlarm.request() !=
        PermissionStatus.granted) {
      debugPrint(
        'Permiso de alarmas exactas denegado. El recordatorio puede no ser preciso.',
      );
    }
  }

  late DateTime startDate;
  late DateTime endDate;
  late List<int> timeParts;
  try {
    startDate = DateTime.parse(start_date);
    endDate = DateTime.parse(end_date);
    timeParts = time_of_day.split(':').map(int.parse).toList();
  } catch (e) {
    throw Exception('Formato de fecha/hora inválido. $e');
  }

  DateTimeComponents? matchDateTimeComponents;
  if (repeat_interval_unit == RepeatIntervalUnit.DAY && repeat_every_n == 1) {
    matchDateTimeComponents = DateTimeComponents.time;
  } else if (repeat_interval_unit == RepeatIntervalUnit.WEEK &&
      repeat_every_n == 1) {
    matchDateTimeComponents = DateTimeComponents.dayOfWeekAndTime;
  }

  tz.TZDateTime scheduleTime = tz.TZDateTime(
    tz.local,
    startDate.year,
    startDate.month,
    startDate.day,
    timeParts[0],
    timeParts[1],
    timeParts[2],
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
