import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/eventos_api.dart';

class AgendaDetailPage extends StatelessWidget {
  const AgendaDetailPage({super.key});

  void _deleteEvent(BuildContext context, Evento evento) async {
    final api = ApiHttp();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Evento"),
        content: const Text("¿Seguro que deseas eliminar esta actividad?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await api.deleteJson('/api/agenda/${evento.idActividad}');

        if (context.mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
        }
      }
    }
  }

  void _editEvent(BuildContext context, Evento evento) async {
    final eventoMap = {
      'id_evento': evento.idActividad,
      'titulo': evento.titulo,
      'mensaje': evento.descripcion,
      'fecha_evento': evento.fechaEvento.toIso8601String(),
      'dias_anticipacion': evento.diasAnticipacion ?? 3,
    };

    final result = await Navigator.pushNamed(
      context,
      'crear_evento',
      arguments: eventoMap,
    );

    if (result == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final evento = ModalRoute.of(context)!.settings.arguments as Evento;
    final primary = const Color.fromRGBO(19, 67, 107, 1);

    String formatTime(String? timeStr) {
      if (timeStr == null || timeStr.isEmpty) return 'Todo el día';
      if (timeStr.length > 5) return timeStr.substring(0, 5);
      return timeStr;
    }

    String formatDate(DateTime date) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(evento.titulo),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: () => _editEvent(context, evento),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteEvent(context, evento),
          ),
        ],
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (evento.imagen != null && evento.imagen!.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  evento.imagen!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) =>
                      Container(height: 200, color: Colors.grey[200]),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              evento.titulo,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _InfoTile(
              icon: Icons.calendar_today,
              label: 'Fecha',
              value: formatDate(evento.fechaEvento),
            ),
            _InfoTile(
              icon: Icons.access_time,
              label: 'Hora',
              value: formatTime(evento.horaEvento),
            ),
            if (evento.diasAnticipacion != null)
              _InfoTile(
                icon: Icons.notifications_active,
                label: 'Avisar desde',
                value: "${evento.diasAnticipacion} días antes",
              ),
            const Divider(height: 32),
            _InfoTile(
              icon: Icons.description_outlined,
              label: 'Descripción',
              value: (evento.descripcion == null || evento.descripcion!.isEmpty)
                  ? 'No hay descripción.'
                  : evento.descripcion!,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[700], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
