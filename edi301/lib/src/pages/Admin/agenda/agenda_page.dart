// lib/src/pages/Admin/agenda/agenda_page.dart
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/eventos_api.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final EventosApi _api = EventosApi();
  late Future<List<Evento>> _eventosFuture;

  @override
  void initState() {
    super.initState();
    _loadEventos();
  }

  void _loadEventos() {
    setState(() {
      _eventosFuture = _api.listar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Agenda'),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
      ),
      body: ResponsiveContent(
        child: FutureBuilder<List<Evento>>(
          future: _eventosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final eventos = snapshot.data ?? [];
            if (eventos.isEmpty) {
              return const Center(child: Text('No hay eventos programados.'));
            }
            return ListView.builder(
              itemCount: eventos.length,
              itemBuilder: (context, index) {
                final evento = eventos[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(evento.fechaEvento.day.toString()),
                  ),
                  title: Text(evento.titulo),
                  subtitle: Text(
                    '${evento.fechaEvento.year}/${evento.fechaEvento.month}/${evento.fechaEvento.day} - ${evento.horaEvento ?? 'Todo el día'}',
                  ),
                  isThreeLine: evento.descripcion != null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      'agenda_detail',
                      arguments: evento,
                    );
                    if (result == true) {
                      _loadEventos();
                    }
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result =
              await Navigator.pushNamed(context, 'crear_evento') as bool?;
          if (result == true) {
            _loadEventos();
          }
        },
        backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
