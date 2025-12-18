// lib/src/pages/Admin/agenda/agenda_detail_page.dart
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/eventos_api.dart'; // Para el modelo Evento

class AgendaDetailPage extends StatelessWidget {
  const AgendaDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Recibe el objeto Evento completo que pasamos desde la lista
    final evento = ModalRoute.of(context)!.settings.arguments as Evento;
    final primary = const Color.fromRGBO(19, 67, 107, 1);

    // Función para formatear la hora (ej. 16:40:00 -> 16:40)
    String formatTime(String? timeStr) {
      if (timeStr == null || timeStr.isEmpty) return 'Todo el día';
      if (timeStr.length > 5) {
        return timeStr.substring(0, 5);
      }
      return timeStr;
    }

    // Función para formatear la fecha (ej. 12/11/2025)
    String formatDate(DateTime date) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(evento.titulo),
        backgroundColor: primary,
        actions: [
          IconButton(
            tooltip: 'Editar (Pendiente)',
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Próximamente
            },
          ),
          IconButton(
            tooltip: 'Eliminar (Pendiente)',
            icon: const Icon(Icons.delete),
            onPressed: () {
              // Próximamente
            },
          ),
        ],
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Mostrar imagen si existe
            if (evento.imagen != null && evento.imagen!.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  evento.imagen!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 100,
                        color: Colors.grey,
                      ),
                    ),
                  ),
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

            // Fecha y Hora
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
            const Divider(height: 32),

            // Descripción
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

// Widget auxiliar para mostrar la información
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
