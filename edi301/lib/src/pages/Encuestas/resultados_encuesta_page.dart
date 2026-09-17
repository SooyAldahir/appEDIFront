import 'package:edi301/core/api_error.dart';
import 'package:edi301/services/encuestas_api.dart';
import 'package:edi301/src/pages/Encuestas/exportar_encuesta_service.dart';
import 'package:flutter/material.dart';

class ResultadosEncuestaPage extends StatefulWidget {
  final int idEncuesta;
  const ResultadosEncuestaPage({super.key, required this.idEncuesta});
  @override
  State<ResultadosEncuestaPage> createState() => _ResultadosEncuestaPageState();
}

class _ResultadosEncuestaPageState extends State<ResultadosEncuestaPage> {
  final api = EncuestasApi();
  late Future<Map<String, dynamic>> future;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    future = api.results(widget.idEncuesta);
  }

  /// Genera el .xlsx y lo abre con la app que el sistema tenga asociada.
  Future<void> _exportar() async {
    setState(() => _exportando = true);
    try {
      await ExportarEncuestaService().exportar(widget.idEncuesta);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Resultados'),
      backgroundColor: const Color(0xFF13436B),
      foregroundColor: Colors.white,
      actions: [
        if (_exportando)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar a Excel',
            onPressed: _exportar,
          ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text(friendlyError(s.error!)));
        final data = s.data!;
        final total = (data['total_respuestas'] as num?)?.toInt() ?? 0;
        final counts = (data['conteos'] as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        final free = (data['respuestas_libres'] as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        final questions = (data['preguntas'] as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              data['titulo'],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '$total respuesta(s) anónima(s)',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...questions.map((q) {
              final id = q['id_pregunta'];
              final type = q['tipo'];
              final options = (q['opciones'] as List)
                  .map((x) => Map<String, dynamic>.from(x as Map))
                  .toList();
              if (type == 'LIBRE') {
                final answers = free
                    .where((x) => x['id_pregunta'] == id)
                    .map((x) => x['texto_libre'].toString())
                    .toList();
                return _freeCard(q['texto'].toString(), answers);
              }
              return _choiceCard(
                q['texto'].toString(),
                options,
                counts.where((x) => x['id_pregunta'] == id).toList(),
                total,
              );
            }),
          ],
        );
      },
    ),
  );
  Widget _choiceCard(
    String title,
    List<Map<String, dynamic>> options,
    List<Map<String, dynamic>> counts,
    int total,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...options.map((o) {
            final count = counts
                .where((x) => x['id_opcion'] == o['id_opcion'])
                .fold<int>(0, (sum, x) => sum + ((x['total'] as num).toInt()));
            final percent = total == 0 ? 0.0 : count * 100 / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(o['texto'])),
                      Text('$count (${percent.toStringAsFixed(0)}%)'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF13436B),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
  Widget _freeCard(String title, List<String> answers) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${answers.length} respuesta(s) anónima(s)',
            style: const TextStyle(color: Colors.grey),
          ),
          const Divider(),
          if (answers.isEmpty)
            const Text('Aún no hay respuestas.')
          else
            ...answers.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('“$a”'),
              ),
            ),
        ],
      ),
    ),
  );
}
