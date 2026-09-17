import 'dart:convert';
import 'package:edi301/core/api_error.dart';
import 'package:edi301/services/encuestas_api.dart';
import 'package:edi301/src/pages/Encuestas/resultados_encuesta_page.dart';
import 'package:edi301/src/pages/Encuestas/muestra_page.dart';
import 'package:edi301/services/poblacion_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncuestasPage extends StatefulWidget {
  const EncuestasPage({super.key});
  @override
  State<EncuestasPage> createState() => _EncuestasPageState();
}

class _EncuestasPageState extends State<EncuestasPage> {
  final api = EncuestasApi();
  late Future<List<dynamic>> future;
  bool admin = false;
  @override
  void initState() {
    super.initState();
    future = api.list();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('user');
    if (raw != null && mounted)
      setState(
        () => admin =
            (jsonDecode(raw)['nombre_rol'] ?? jsonDecode(raw)['rol']) ==
            'Admin',
      );
  }

  void load() {
    setState(() {
      future = api.list();
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('Encuestas'),
      backgroundColor: const Color(0xFF13436B),
      foregroundColor: Colors.white,
    ),
    floatingActionButton: admin
        ? FloatingActionButton.extended(
            backgroundColor: const Color(0xFFF5BC06),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add),
            label: const Text('Nueva encuesta'),
            onPressed: () async {
              final done = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CrearEncuestaPage()),
              );
              if (done == true) load();
            },
          )
        : null,
    body: FutureBuilder<List<dynamic>>(
      future: future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text(friendlyError(s.error!)));
        final list = s.data ?? [];
        if (list.isEmpty)
          return RefreshIndicator(
            onRefresh: () async => load(),
            child: ListView(
              children: [
                const SizedBox(height: 180),
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.poll_outlined,
                        size: 72,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        admin
                            ? 'Aún no has creado encuestas.'
                            : 'No hay encuestas disponibles.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        return RefreshIndicator(
          onRefresh: () async => load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (c, i) {
              final x = Map<String, dynamic>.from(list[i] as Map);
              final canAnswer = x['respondida'] != true && x['abierta'] == true;
              return Card(
                child: ListTile(
                  leading: Icon(
                    x['estado'] == 'CERRADA' ? Icons.lock_outline : Icons.poll,
                    color: const Color(0xFF13436B),
                  ),
                  title: Text(x['titulo']),
                  subtitle: Row(
                    children: [
                      Flexible(
                        child: Text(
                          x['respondida'] == true
                              ? 'Respuesta enviada'
                              : canAnswer
                              ? 'Disponible para responder'
                              : x['estado'] == 'BORRADOR'
                              ? 'Borrador'
                              : 'Cerrada',
                        ),
                      ),
                      if (x['audiencia'] == 'MUESTRA') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13436B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'MUESTRA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Para el admin hay dos destinos por encuesta (resultados
                  // y muestra), asi que el chevron se cambia por un menu.
                  trailing: admin
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (opcion) {
                            final id = x['id_encuesta'] as int;
                            if (opcion == 'resultados') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ResultadosEncuestaPage(idEncuesta: id),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MuestraEncuestaPage(
                                    idEncuesta: id,
                                    titulo: '${x['titulo']}',
                                  ),
                                ),
                              ).then((_) => load());
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'resultados',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.bar_chart),
                                title: Text('Ver resultados'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'muestra',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.shuffle),
                                title: Text('Muestra aleatoria'),
                              ),
                            ),
                          ],
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: admin
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultadosEncuestaPage(
                              idEncuesta: x['id_encuesta'] as int,
                            ),
                          ),
                        )
                      : canAnswer
                      ? () async {
                          await Navigator.push(
                            c,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ResponderEncuestaPage(encuesta: x),
                            ),
                          );
                          load();
                        }
                      : null,
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class CrearEncuestaPage extends StatefulWidget {
  const CrearEncuestaPage({super.key});
  @override
  State<CrearEncuestaPage> createState() => _CrearEncuestaPageState();
}

class _CrearEncuestaPageState extends State<CrearEncuestaPage> {
  final api = EncuestasApi();
  final poblacionApi = PoblacionApi();
  final title = TextEditingController();
  final description = TextEditingController();
  final questions = <_DraftQuestion>[_DraftQuestion()];
  bool publish = true, saving = false;

  // ── Audiencia ─────────────────────────────────────────────────
  // Se decide aqui y no despues: la encuesta se crea ya restringida, asi
  // que nunca llega a estar visible para quien no fue sorteado.
  bool porMuestra = false;
  bool porCuotas = false;
  bool incluirColivi = false;
  final tamanoCtrl = TextEditingController(text: '100');
  final cuotaPadresCtrl = TextEditingController();
  final cuotaHijosCtrl = TextEditingController();

  int padresDisponibles = 0;
  int hijosDisponibles = 0;
  bool cargandoPoblacion = false;

  int get elegibles => padresDisponibles + hijosDisponibles;

  @override
  void initState() {
    super.initState();
    _cargarPoblacion();
  }

  /// El conteo es solo informativo: si falla, el formulario sigue sirviendo y
  /// el servidor valida las cantidades de todos modos.
  Future<void> _cargarPoblacion() async {
    setState(() => cargandoPoblacion = true);
    try {
      final censo = await poblacionApi.resumen();
      final totales = Map<String, dynamic>.from(censo['totales'] as Map);
      if (!mounted) return;
      setState(() {
        padresDisponibles = (totales['padres'] as num?)?.toInt() ?? 0;
        hijosDisponibles = (totales['hijos'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      // Silencioso a proposito.
    } finally {
      if (mounted) setState(() => cargandoPoblacion = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    tamanoCtrl.dispose();
    cuotaPadresCtrl.dispose();
    cuotaHijosCtrl.dispose();
    for (final q in questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      _error('Escribe un título.');
      return;
    }
    if (questions.length > 50) {
      _error('El máximo es 50 preguntas.');
      return;
    }
    for (final q in questions) {
      if (q.text.text.trim().isEmpty) {
        _error('Todas las preguntas deben tener texto.');
        return;
      }
      if (q.type != 'LIBRE' &&
          q.options.where((x) => x.text.trim().isNotEmpty).length < 2) {
        _error('Las preguntas de opciones requieren al menos dos opciones.');
        return;
      }
    }
    Map<String, dynamic>? muestra;
    if (porMuestra) {
      if (porCuotas) {
        final p = int.tryParse(cuotaPadresCtrl.text.trim()) ?? 0;
        final h = int.tryParse(cuotaHijosCtrl.text.trim()) ?? 0;
        if (p + h == 0) {
          _error('Indica cuantos padres y cuantos hijos quieres en la muestra.');
          return;
        }
        if (p > padresDisponibles || h > hijosDisponibles) {
          _error('No hay tantas personas disponibles en alguno de los grupos.');
          return;
        }
        muestra = {'cuotas': {'PADRES': p, 'HIJOS': h}};
      } else {
        final n = int.tryParse(tamanoCtrl.text.trim()) ?? 0;
        if (n <= 0) {
          _error('Indica el tamano de la muestra.');
          return;
        }
        muestra = {'tamano': n};
      }
      muestra['incluir_colivi'] = incluirColivi;
    }

    setState(() => saving = true);
    try {
      await api.create({
        'titulo': title.text.trim(),
        'descripcion': description.text.trim(),
        'estado': publish ? 'PUBLICADA' : 'BORRADOR',
        'audiencia': porMuestra ? 'MUESTRA' : 'TODOS',
        if (muestra != null) 'muestra': muestra,
        'preguntas': questions
            .map(
              (q) => {
                'texto': q.text.text.trim(),
                'tipo': q.type,
                'requerida': q.required,
                'opciones': q.type == 'LIBRE'
                    ? <String>[]
                    : q.options
                          .where((x) => x.text.trim().isNotEmpty)
                          .map((x) => x.text.trim())
                          .toList(),
              },
            )
            .toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _error(friendlyError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _error(String m) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('Nueva encuesta'),
      backgroundColor: const Color(0xFF13436B),
      foregroundColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: title,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Título *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Descripción (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          value: publish,
          onChanged: (v) => setState(() => publish = v),
          title: const Text('Publicar al guardar'),
          subtitle: const Text('Si no, quedará como borrador.'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        _bloqueAudiencia(),
        const Divider(height: 28),
        ...questions.asMap().entries.map((e) => _questionCard(e.key, e.value)),
        if (questions.length < 50)
          OutlinedButton.icon(
            onPressed: () => setState(() => questions.add(_DraftQuestion())),
            icon: const Icon(Icons.add),
            label: Text('Agregar pregunta (${questions.length}/50)'),
          ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.publish),
          label: Text(
            saving
                ? 'Guardando...'
                : publish
                ? (porMuestra ? 'Sortear y publicar' : 'Publicar encuesta')
                : 'Guardar borrador',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF13436B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(15),
          ),
        ),
      ],
    ),
  );
  // ── Para quien es la encuesta ──────────────────────────────────

  Widget _bloqueAudiencia() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Para quién es',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13436B)),
        ),
        const SizedBox(height: 10),
        RadioListTile<bool>(
          value: false,
          groupValue: porMuestra,
          onChanged: (v) => setState(() => porMuestra = v ?? false),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Todos los usuarios'),
          subtitle: const Text(
            'Cualquiera con cuenta activa puede responderla.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        RadioListTile<bool>(
          value: true,
          groupValue: porMuestra,
          onChanged: (v) => setState(() => porMuestra = v ?? false),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Una muestra aleatoria'),
          subtitle: const Text(
            'Solo las personas sorteadas la verán y podrán responderla.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        if (porMuestra) ...[
          const SizedBox(height: 6),
          if (cargandoPoblacion)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            Text(
              elegibles == 0
                  ? 'No se pudo consultar la población. Puedes continuar: el '
                        'servidor validará las cantidades.'
                  : 'Disponibles: $padresDisponibles padres y $hijosDisponibles '
                        'hijos (${elegibles} en total)'
                        '${incluirColivi ? "" : ", sin COLIVI"}.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Por total')),
              ButtonSegment(value: true, label: Text('Por cuotas')),
            ],
            selected: {porCuotas},
            onSelectionChanged: (x) => setState(() => porCuotas = x.first),
          ),
          const SizedBox(height: 12),
          if (!porCuotas) ...[
            TextField(
              controller: tamanoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cuántas personas',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Text(
              _previewReparto(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cuotaPadresCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Padres',
                      helperText: 'máx. $padresDisponibles',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: cuotaHijosCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Hijos',
                      helperText: 'máx. $hijosDisponibles',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          SwitchListTile(
            value: incluirColivi,
            onChanged: (v) => setState(() => incluirColivi = v),
            title: const Text(
              'Incluir alumnos de COLIVI',
              style: TextStyle(fontSize: 14),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: const Color(0xFF13436B),
          ),
        ],
      ],
    ),
  );

  /// Reparto proporcional aproximado, solo para que se vea antes de guardar.
  /// El cálculo bueno lo hace el servidor (restos mayores).
  String _previewReparto() {
    final n = int.tryParse(tamanoCtrl.text.trim()) ?? 0;
    if (n <= 0 || elegibles == 0) return '';
    if (n >= elegibles) return 'Se invitaría a toda la población elegible.';
    final padres = (padresDisponibles * n / elegibles).round();
    return 'Aproximadamente $padres padres y ${n - padres} hijos, '
        'respetando la proporción real.';
  }

  Widget _questionCard(int i, _DraftQuestion q) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pregunta ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (questions.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    q.dispose();
                    questions.removeAt(i);
                  }),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          TextField(
            controller: q.text,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Pregunta *'),
          ),
          DropdownButtonFormField<String>(
            initialValue: q.type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'UNICA', child: Text('Opción única')),
              DropdownMenuItem(
                value: 'MULTIPLE',
                child: Text('Opción múltiple'),
              ),
              DropdownMenuItem(value: 'LIBRE', child: Text('Respuesta libre')),
            ],
            onChanged: (v) => setState(() => q.type = v!),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: q.required,
            onChanged: (v) => setState(() => q.required = v),
            title: const Text('Respuesta obligatoria'),
          ),
          if (q.type != 'LIBRE') ...[_options(q)],
        ],
      ),
    ),
  );
  Widget _options(_DraftQuestion q) => Column(
    children: [
      ...q.options.asMap().entries.map(
        (e) => Row(
          children: [
            Expanded(
              child: TextField(
                controller: e.value,
                decoration: InputDecoration(labelText: 'Opción ${e.key + 1}'),
              ),
            ),
            if (q.options.length > 2)
              IconButton(
                onPressed: () => setState(() {
                  e.value.dispose();
                  q.options.removeAt(e.key);
                }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: () => setState(() => q.options.add(TextEditingController())),
        icon: const Icon(Icons.add),
        label: const Text('Agregar opción'),
      ),
    ],
  );
}

class _DraftQuestion {
  final text = TextEditingController();
  String type = 'UNICA';
  bool required = true;
  final options = [TextEditingController(), TextEditingController()];
  void dispose() {
    text.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

class ResponderEncuestaPage extends StatefulWidget {
  final Map<String, dynamic> encuesta;
  const ResponderEncuestaPage({super.key, required this.encuesta});
  @override
  State<ResponderEncuestaPage> createState() => _ResponderState();
}

class _ResponderState extends State<ResponderEncuestaPage> {
  final api = EncuestasApi();
  Map<String, dynamic>? survey;
  bool saving = false;
  final values = <int, dynamic>{};
  @override
  void initState() {
    super.initState();
    api.get(widget.encuesta['id_encuesta']).then((v) {
      if (mounted) setState(() => survey = v);
    });
  }

  @override
  Widget build(BuildContext c) {
    final s = survey;
    if (s == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final qs = s['preguntas'] as List;
    return Scaffold(
      appBar: AppBar(
        title: Text(s['titulo']),
        backgroundColor: const Color(0xFF13436B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if ((s['descripcion'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s['descripcion']),
            ),
          ...qs.map((raw) {
            final q = Map<String, dynamic>.from(raw as Map);
            final id = q['id_pregunta'] as int;
            final type = q['tipo'];
            final opts = q['opciones'] as List;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q['texto'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (type == 'LIBRE')
                      TextField(maxLines: 3, onChanged: (v) => values[id] = v)
                    else if (type == 'UNICA')
                      ...opts.map((o) {
                        final m = Map<String, dynamic>.from(o as Map);
                        return RadioListTile<int>(
                          value: m['id_opcion'],
                          groupValue: values[id],
                          title: Text(m['texto']),
                          onChanged: (v) => setState(() => values[id] = v),
                        );
                      })
                    else
                      ...opts.map((o) {
                        final m = Map<String, dynamic>.from(o as Map);
                        final selected =
                            (values[id] as Set<int>?)?.contains(
                              m['id_opcion'],
                            ) ??
                            false;
                        return CheckboxListTile(
                          value: selected,
                          title: Text(m['texto']),
                          onChanged: (v) => setState(() {
                            final set = Set<int>.from(values[id] ?? <int>{});
                            v == true
                                ? set.add(m['id_opcion'])
                                : set.remove(m['id_opcion']);
                            values[id] = set;
                          }),
                        );
                      }),
                  ],
                ),
              ),
            );
          }),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      final a = qs.map((raw) {
                        final q = Map<String, dynamic>.from(raw as Map);
                        final v = values[q['id_pregunta']];
                        return {
                          'id_pregunta': q['id_pregunta'],
                          if (q['tipo'] == 'LIBRE') 'texto_libre': v ?? '',
                          if (q['tipo'] != 'LIBRE')
                            'opciones': v is Set<int>
                                ? v.toList()
                                : v == null
                                ? <int>[]
                                : [v],
                        };
                      }).toList();
                      await api.submit(s['id_encuesta'], a);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(friendlyError(e))),
                        );
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'Enviando...' : 'Enviar respuesta'),
          ),
        ],
      ),
    );
  }
}
