// lib/src/pages/Admin/agenda/agenda_controller.dart
import 'package:flutter/material.dart';
import 'package:edi301/services/eventos_api.dart';
// Importa el tool de recordatorios
import 'package:edi301/tools/generic_reminders.dart' as reminders_tool;

class AgendaController {
  late BuildContext context;
  final EventosApi _api = EventosApi();
  final loading = ValueNotifier<bool>(false);

  // Controladores del formulario
  final tituloCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final imagenCtrl = TextEditingController();
  DateTime? fechaEvento;
  TimeOfDay? horaEvento;

  final crearRecordatorio = ValueNotifier<bool>(false);

  final recordatorioHoraCtrl = TextEditingController(text: '13:00');
  final recordatorioDiasAntesCtrl = TextEditingController(text: '7');
  String recordatorioTipo = 'DAY';

  void init(BuildContext context) {
    this.context = context;
    fechaEvento = DateTime.now().add(const Duration(days: 1));
  }

  void dispose() {
    tituloCtrl.dispose();
    descCtrl.dispose();
    imagenCtrl.dispose();
    crearRecordatorio.dispose();
    recordatorioHoraCtrl.dispose();
    recordatorioDiasAntesCtrl.dispose();
    loading.dispose();
  }

  Future<void> guardarEvento() async {
    loading.value = true;

    if (fechaEvento == null) {
      _snack('Debes seleccionar una fecha para el evento.');
      loading.value = false;
      return;
    }

    try {
      await _api.crearEvento(
        titulo: tituloCtrl.text,
        fecha: fechaEvento!,
        hora: horaEvento?.to24HourString(),
        descripcion: descCtrl.text,
        imagenUrl: imagenCtrl.text,
      );
      if (crearRecordatorio.value) {
        await _crearRecordatorioRecurrente();
      }

      if (context.mounted) {
        _snack('Evento creado con éxito', isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      loading.value = false;
    }
  }

  Future<void> _crearRecordatorioRecurrente() async {
    try {
      final diasAntes = int.parse(recordatorioDiasAntesCtrl.text);
      final hora = recordatorioHoraCtrl.text.trim();
      final fechaFin = fechaEvento!;
      final fechaInicio = fechaFin.subtract(Duration(days: diasAntes));
      final String startDateStr = fechaInicio
          .toIso8601String()
          .split('T')
          .first;
      final String endDateStr = fechaFin.toIso8601String().split('T').first;
      final String timeStr = (hora.length == 5) ? '$hora:00' : '13:00:00';
      await reminders_tool.createReminder(
        title: tituloCtrl.text,
        description: descCtrl.text,
        start_date: startDateStr,
        end_date: endDateStr,
        time_of_day: timeStr,
        repeat_interval_unit: recordatorioTipo == 'DAY'
            ? reminders_tool.RepeatIntervalUnit.DAY
            : reminders_tool.RepeatIntervalUnit.WEEK,
        repeat_every_n: 1,
      );
    } catch (e) {
      _snack('Evento guardado, pero falló al crear el recordatorio: $e');
    }
  }

  void _snack(String msg, {bool isError = true}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }
}

extension TimeOfDayExtension on TimeOfDay {
  String to24HourString() {
    final String hourStr = hour.toString().padLeft(2, '0');
    final String minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }
}
