// lib/src/pages/Admin/family_detail/edit_family_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/services/members_api.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';
import 'package:intl/intl.dart';

class EditFamilyPage extends StatefulWidget {
  final Family family;
  const EditFamilyPage({super.key, required this.family});

  @override
  State<EditFamilyPage> createState() => _EditFamilyPageState();
}

class _EditFamilyPageState extends State<EditFamilyPage> {
  static const _navy = Color.fromRGBO(19, 67, 107, 1);

  final FamiliaApi _familiaApi = FamiliaApi();
  final MembersApi _membersApi = MembersApi();
  final _formKey = GlobalKey<FormState>();
  final ApiHttp _api = ApiHttp();

  late TextEditingController _nombreCtrl;
  late TextEditingController _direccionCtrl;
  String _residencia = 'INTERNA';

  // Padre / Madre
  final TextEditingController _papaSearchCtrl = TextEditingController();
  final TextEditingController _mamaSearchCtrl = TextEditingController();
  Map<String, dynamic>? _selectedPapa;
  Map<String, dynamic>? _selectedMama;
  List<Map<String, dynamic>> _papaResults = [];
  List<Map<String, dynamic>> _mamaResults = [];
  Timer? _papaDebounce;
  Timer? _mamaDebounce;

  // Hijos sanguíneos (tipo_miembro = HIJO)
  late List<FamilyMember> _hijos;
  final TextEditingController _hijoSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _hijoResults = [];
  Timer? _hijoDebounce;

  // Hijos EDI / alumnos asignados (tipo_miembro = ALUMNO_ASIGNADO).
  // Son los únicos que ocupan cupo según el límite configurado.
  late List<FamilyMember> _alumnos;
  final TextEditingController _alumnoSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _alumnoResults = [];
  Timer? _alumnoDebounce;

  // Tíos EDI (empleados o alumnos; no cuentan como hijos)
  late List<FamilyMember> _tios;
  final TextEditingController _tioSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _tioResults = [];
  Timer? _tioDebounce;

  // Hijos del hogar sin cuenta
  late List<HogarChild> _hogarChildren;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.family;
    _nombreCtrl = TextEditingController(text: f.familyName);
    _direccionCtrl = TextEditingController(text: f.direccion ?? '');
    _residencia = (f.residencia?.toUpperCase().startsWith('INT') ?? true)
        ? 'INTERNA'
        : 'EXTERNA';

    if (f.fatherEmployeeId != null) {
      _selectedPapa = {
        'id_usuario': f.fatherEmployeeId,
        'display': f.fatherName ?? '',
      };
      _papaSearchCtrl.text = f.fatherName ?? '';
    }
    if (f.motherEmployeeId != null) {
      _selectedMama = {
        'id_usuario': f.motherEmployeeId,
        'display': f.motherName ?? '',
      };
      _mamaSearchCtrl.text = f.motherName ?? '';
    }
    // Cada rol arranca de SU propia lista del modelo.
    _hijos = List<FamilyMember>.from(f.householdChildren);
    _alumnos = List<FamilyMember>.from(f.assignedStudents);
    _tios = List<FamilyMember>.from(f.uncles);
    _hogarChildren = List<HogarChild>.from(f.hogarChildren);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _papaSearchCtrl.dispose();
    _mamaSearchCtrl.dispose();
    _hijoSearchCtrl.dispose();
    _alumnoSearchCtrl.dispose();
    _tioSearchCtrl.dispose();
    _papaDebounce?.cancel();
    _mamaDebounce?.cancel();
    _hijoDebounce?.cancel();
    _alumnoDebounce?.cancel();
    _tioDebounce?.cancel();
    super.dispose();
  }

  // ── Search helpers ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _searchUsers(String q, String tipo) async {
    if (q.trim().isEmpty) return [];
    try {
      final res = await _api.getJson(
        '/api/usuarios',
        query: {'tipo': tipo, 'q': q.trim()},
      );
      if (res.statusCode >= 400) return [];
      final decoded = jsonDecode(res.body);
      final list = decoded is List
          ? decoded
          : (decoded is Map && decoded['data'] is List)
          ? decoded['data'] as List
          : [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  String _userName(Map<String, dynamic> u) =>
      '${u['Nombre'] ?? u['nombre'] ?? ''} ${u['Apellido'] ?? u['apellido'] ?? ''}'
          .trim();

  int _userId(Map<String, dynamic> u) {
    final raw = u['IdUsuario'] ?? u['id_usuario'] ?? 0;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  int? _userMatricula(Map<String, dynamic> u) {
    final raw = u['Matricula'] ?? u['matricula'];
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().trim());
  }

  // ── Debounced search triggers ───────────────────────────────────────────────
  /// Busca empleados Y tutores externos y fusiona resultados (sin duplicados).
  Future<List<Map<String, dynamic>>> _searchParents(String q) async {
    final results = await Future.wait([
      _searchUsers(q, 'EMPLEADO'),
      _searchUsers(q, 'EXTERNO'),
    ]);
    final merged = <int, Map<String, dynamic>>{};
    for (final list in results) {
      for (final u in list) {
        merged[_userId(u)] = u;
      }
    }
    return merged.values.toList();
  }

  void _onPapaSearch(String q) {
    _papaDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _papaResults = [];
        _selectedPapa = null;
      });
      return;
    }
    _papaDebounce = Timer(const Duration(milliseconds: 400), () async {
      final r = await _searchParents(q);
      if (mounted) setState(() => _papaResults = r);
    });
  }

  void _onMamaSearch(String q) {
    _mamaDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _mamaResults = [];
        _selectedMama = null;
      });
      return;
    }
    _mamaDebounce = Timer(const Duration(milliseconds: 400), () async {
      final r = await _searchParents(q);
      if (mounted) setState(() => _mamaResults = r);
    });
  }

  /// Busca en los tipos indicados y descarta a quien ya es miembro de esta
  /// familia con cualquier rol, para no ofrecer duplicados.
  Future<List<Map<String, dynamic>>> _searchDisponibles(
    String q,
    List<String> tipos,
  ) async {
    final results = await Future.wait(tipos.map((t) => _searchUsers(q, t)));
    final merged = <int, Map<String, dynamic>>{};
    for (final list in results) {
      for (final user in list) {
        final id = _userId(user);
        if (id != 0 && _rolExistente(id) == null) merged[id] = user;
      }
    }
    return merged.values.toList();
  }

  void _onHijoSearch(String q) {
    _hijoDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _hijoResults = []);
      return;
    }
    _hijoDebounce = Timer(const Duration(milliseconds: 400), () async {
      final r = await _searchDisponibles(q, const ['ALUMNO']);
      if (mounted) setState(() => _hijoResults = r);
    });
  }

  void _onAlumnoSearch(String q) {
    _alumnoDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _alumnoResults = []);
      return;
    }
    _alumnoDebounce = Timer(const Duration(milliseconds: 400), () async {
      final r = await _searchDisponibles(q, const ['ALUMNO']);
      if (mounted) setState(() => _alumnoResults = r);
    });
  }

  void _onTioSearch(String q) {
    _tioDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _tioResults = []);
      return;
    }
    _tioDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _searchDisponibles(q, const [
        'ALUMNO',
        'EMPLEADO',
      ]);
      if (mounted) setState(() => _tioResults = results);
    });
  }

  // ── Alta / baja de miembros ────────────────────────────────────────────────
  /// Una persona solo puede ocupar UN rol dentro de la misma familia
  /// (la BD tiene un índice único sobre id_familia + id_usuario).
  FamilyMember? _rolExistente(int idUsuario) {
    for (final lista in [_hijos, _alumnos, _tios]) {
      for (final m in lista) {
        if (m.idUsuario == idUsuario) return m;
      }
    }
    return null;
  }

  void _toast(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  /// Alta genérica: sirve para hijo sanguíneo, hijo EDI y tío EDI.
  Future<void> _addMiembro({
    required Map<String, dynamic> user,
    required String tipo,
    required List<FamilyMember> destino,
    required TextEditingController searchCtrl,
    required void Function() limpiarResultados,
  }) async {
    final id = _userId(user);
    if (id == 0) return;

    final yaEsta = _rolExistente(id);
    if (yaEsta != null) {
      _toast(
        '${yaEsta.fullName} ya está en esta familia como ${yaEsta.roleLabel}.',
        Colors.orange.shade800,
      );
      return;
    }

    final nombre = _userName(user);
    try {
      final idMiembro = await _membersApi.addMember(
        idFamilia: widget.family.id!,
        idUsuario: id,
        tipoMiembro: tipo,
      );
      if (!mounted) return;
      setState(() {
        destino.add(
          FamilyMember(
            // Guardamos el id real para poder quitarlo sin recargar.
            idMiembro: idMiembro ?? 0,
            idUsuario: id,
            fullName: nombre,
            tipoMiembro: tipo,
            matricula: _userMatricula(user),
          ),
        );
        destino.sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
        searchCtrl.clear();
        limpiarResultados();
      });
      _toast('$nombre agregado como ${MemberType.label(tipo)}.', Colors.green);
    } catch (e) {
      _toast(friendlyError(e), Colors.red.shade700);
    }
  }

  /// Baja genérica, con confirmación y el rol correcto en el mensaje.
  Future<void> _removeMiembro(
    FamilyMember m,
    List<FamilyMember> origen,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('¿Quitar ${m.roleLabel.toLowerCase()}?'),
        content: Text('¿Quitar a ${m.fullName} de la familia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Sin id_miembro no podemos borrar en el servidor: avisamos en vez de
    // quitarlo solo de la pantalla y dejar la BD desincronizada.
    if (m.idMiembro == 0) {
      _toast(
        'No se pudo identificar el registro. Recarga la familia e inténtalo de nuevo.',
        Colors.red.shade700,
      );
      return;
    }

    try {
      await _membersApi.removeMember(m.idMiembro);
      if (!mounted) return;
      setState(() => origen.removeWhere((x) => x.idUsuario == m.idUsuario));
      _toast('${m.fullName} quitado de la familia.', Colors.orange);
    } catch (e) {
      _toast(friendlyError(e), Colors.red.shade700);
    }
  }

  // ── Save family basic info ──────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _familiaApi.updateFamily(
        id: widget.family.id!,
        nombreFamilia: _nombreCtrl.text.trim(),
        residencia: _residencia,
        direccion: _direccionCtrl.text.trim().isEmpty
            ? null
            : _direccionCtrl.text.trim(),
        papaId: _selectedPapa?['id_usuario'] as int?,
        mamaId: _selectedMama?['id_usuario'] as int?,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Familia'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: 'Guardar cambios',
                  onPressed: _save,
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Nombre ──────────────────────────────────────────────────────
            _sectionTitle('Nombre de la familia'),
            TextFormField(
              controller: _nombreCtrl,
              decoration: _inputDeco('Nombre', Icons.family_restroom),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 20),

            // ── Residencia ───────────────────────────────────────────────────
            _sectionTitle('Residencia'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'INTERNA',
                  label: Text('Interna'),
                  icon: Icon(Icons.home),
                ),
                ButtonSegment(
                  value: 'EXTERNA',
                  label: Text('Externa'),
                  icon: Icon(Icons.directions_walk),
                ),
              ],
              selected: {_residencia},
              onSelectionChanged: (s) {
                setState(() {
                  _residencia = s.first;
                  // Las familias INTERNAS no tienen dirección externa
                  if (s.first == 'INTERNA') _direccionCtrl.clear();
                });
                _formKey.currentState?.validate();
              },
            ),
            const SizedBox(height: 16),

            // ── Dirección ────────────────────────────────────────────────────
            TextFormField(
              controller: _direccionCtrl,
              decoration: _inputDeco(
                _residencia == 'EXTERNA'
                    ? 'Dirección (requerida para EXTERNA)'
                    : 'Dirección (opcional)',
                Icons.location_on,
              ),
              validator: (v) {
                if (_residencia == 'EXTERNA' &&
                    (v == null || v.trim().length < 5)) {
                  return 'Ingresa la dirección (mín. 5 caracteres) cuando la residencia es EXTERNA';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── 1. Padres de familia ─────────────────────────────────────────
            _roleHeader(
              'Padres de familia',
              _padresAsignados,
              Icons.volunteer_activism,
              _navy,
            ),
            _sectionHint('Papá y mamá EDI titulares de la familia.'),
            const SizedBox(height: 8),

            _sectionTitle('Papá EDI'),
            _buildPersonSearch(
              controller: _papaSearchCtrl,
              results: _papaResults,
              selected: _selectedPapa,
              onChanged: _onPapaSearch,
              onSelect: (u) => setState(() {
                _selectedPapa = {
                  'id_usuario': _userId(u),
                  'display': _userName(u),
                };
                _papaSearchCtrl.text = _userName(u);
                _papaResults = [];
              }),
              onClear: () => setState(() {
                _selectedPapa = null;
                _papaSearchCtrl.clear();
                _papaResults = [];
              }),
              hint: 'Buscar por nombre o núm. empleado',
              icon: Icons.man,
            ),
            const SizedBox(height: 20),

            // Mamá
            _sectionTitle('Mamá EDI'),
            _buildPersonSearch(
              controller: _mamaSearchCtrl,
              results: _mamaResults,
              selected: _selectedMama,
              onChanged: _onMamaSearch,
              onSelect: (u) => setState(() {
                _selectedMama = {
                  'id_usuario': _userId(u),
                  'display': _userName(u),
                };
                _mamaSearchCtrl.text = _userName(u);
                _mamaResults = [];
              }),
              onClear: () => setState(() {
                _selectedMama = null;
                _mamaSearchCtrl.clear();
                _mamaResults = [];
              }),
              hint: 'Buscar por nombre o núm. empleado',
              icon: Icons.woman,
            ),
            const SizedBox(height: 24),

            // ── 2. Hijos sanguíneos ──────────────────────────────────────────
            ..._memberSection(
              titulo: 'Hijos sanguíneos',
              hint: 'Hijos propios del papá y la mamá EDI, con cuenta en la app.',
              icono: Icons.family_restroom,
              color: Colors.teal.shade700,
              miembros: _hijos,
              emptyText: 'Sin hijos sanguíneos registrados.',
              searchCtrl: _hijoSearchCtrl,
              resultados: _hijoResults,
              onSearch: _onHijoSearch,
              searchHint: 'Agregar hijo sanguíneo por nombre o matrícula',
              onAdd: (u) => _addMiembro(
                user: u,
                tipo: MemberType.hijoSanguineo,
                destino: _hijos,
                searchCtrl: _hijoSearchCtrl,
                limpiarResultados: () => _hijoResults = [],
              ),
              onRemove: (m) => _removeMiembro(m, _hijos),
            ),
            const SizedBox(height: 24),

            // ── 3. Hijos del hogar (sin cuenta) ──────────────────────────────
            _roleHeader(
              'Hijos del hogar',
              _hogarChildren.length,
              Icons.child_care,
              Colors.brown.shade600,
              trailing: TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                style: TextButton.styleFrom(foregroundColor: _navy),
                onPressed: () => _showHogarChildDialog(),
              ),
            ),
            _sectionHint('Niños pequeños que viven en la casa y todavía no tienen cuenta en el sistema.'),
            const SizedBox(height: 8),
            if (_hogarChildren.isEmpty)
              _emptyRow('Sin niños del hogar registrados.')
            else
              ..._hogarChildren.map(
                (h) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFD6EAF8),
                      child: Icon(Icons.child_care, size: 16, color: _navy),
                    ),
                    title: Text(
                      h.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: h.fechaNacimiento != null
                        ? Text(
                            'Nac: ${h.fechaNacimiento}',
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      onPressed: () => _removeHogarChild(h),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // ── 4. Hijos EDI (alumnos asignados) ─────────────────────────────
            ..._memberSection(
              titulo: 'Hijos EDI',
              hint: 'Alumnos asignados a la familia. Son los únicos que ocupan cupo según el límite configurado.',
              icono: Icons.school,
              color: const Color(0xFFB88A00),
              miembros: _alumnos,
              emptyText: 'Sin alumnos EDI asignados.',
              searchCtrl: _alumnoSearchCtrl,
              resultados: _alumnoResults,
              onSearch: _onAlumnoSearch,
              searchHint: 'Agregar hijo EDI por nombre o matrícula',
              onAdd: (u) => _addMiembro(
                user: u,
                tipo: MemberType.alumnoEdi,
                destino: _alumnos,
                searchCtrl: _alumnoSearchCtrl,
                limpiarResultados: () => _alumnoResults = [],
              ),
              onRemove: (m) => _removeMiembro(m, _alumnos),
            ),
            const SizedBox(height: 24),

            // ── 5. Tíos EDI ──────────────────────────────────────────────────
            ..._memberSection(
              titulo: 'Tíos EDI',
              hint: 'Alumnos o empleados que apoyan a la familia. No ocupan cupo de hijos EDI.',
              icono: Icons.handshake,
              color: Colors.indigo.shade600,
              miembros: _tios,
              emptyText: 'Sin tíos EDI asignados.',
              searchCtrl: _tioSearchCtrl,
              resultados: _tioResults,
              onSearch: _onTioSearch,
              searchHint: 'Agregar tío por nombre, matrícula o No. empleado',
              onAdd: (u) => _addMiembro(
                user: u,
                tipo: MemberType.tioEdi,
                destino: _tios,
                searchCtrl: _tioSearchCtrl,
                limpiarResultados: () => _tioResults = [],
              ),
              onRemove: (m) => _removeMiembro(m, _tios),
            ),

            const SizedBox(height: 32),

            // ── Guardar ───────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'GUARDANDO...' : 'GUARDAR CAMBIOS'),
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hijos del hogar sin cuenta ─────────────────────────────────────────────
  Future<void> _showHogarChildDialog() async {
    final nombreCtrl = TextEditingController();
    final apellidoCtrl = TextEditingController();
    DateTime? selectedDate;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.child_care, color: _navy),
              SizedBox(width: 8),
              Text('Agregar niño sin cuenta', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre(s) *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: apellidoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Apellido(s) *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().subtract(
                          const Duration(days: 365 * 5),
                        ),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDlg(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de nacimiento',
                        prefixIcon: Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        selectedDate != null
                            ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                            : 'Seleccionar (opcional)',
                        style: TextStyle(
                          color: selectedDate != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                await _saveHogarChild(
                  nombre: nombreCtrl.text.trim(),
                  apellido: apellidoCtrl.text.trim(),
                  fechaNacimiento: selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                      : null,
                );
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveHogarChild({
    required String nombre,
    required String apellido,
    String? fechaNacimiento,
  }) async {
    try {
      final created = await _familiaApi.createHogarChild(
        idFamilia: widget.family.id!,
        nombre: nombre,
        apellido: apellido,
        fechaNacimiento: fechaNacimiento,
      );
      if (mounted) {
        setState(() => _hogarChildren.add(created));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${created.fullName} agregado.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _removeHogarChild(HogarChild h) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Quitar niño?'),
        content: Text('¿Quitar a ${h.fullName} de la familia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (h.idHijo != null) await _familiaApi.deleteHogarChild(h.idHijo!);
      setState(
        () => _hogarChildren.removeWhere(
          (x) => x.idHijo == h.idHijo && x.fullName == h.fullName,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quitado correctamente.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: _navy,
        letterSpacing: 0.3,
      ),
    ),
  );

  /// Cuántos padres titulares tiene la familia ahora mismo (0, 1 o 2).
  int get _padresAsignados =>
      (_selectedPapa != null ? 1 : 0) + (_selectedMama != null ? 1 : 0);

  /// Encabezado de rol: mismo estilo que el detalle de familia y "Mi familia".
  Widget _roleHeader(
    String titulo,
    int cantidad,
    IconData icono,
    Color color, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icono, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$cantidad',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _sectionHint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
    ),
  );

  Widget _emptyRow(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: const TextStyle(color: Colors.grey)),
  );

  /// Bloque completo de un rol: encabezado + lista actual + buscador para
  /// agregar. Se usa igual para hijos sanguíneos, hijos EDI y tíos EDI, así
  /// que las tres secciones se ven y se comportan idéntico.
  List<Widget> _memberSection({
    required String titulo,
    required String hint,
    required IconData icono,
    required Color color,
    required List<FamilyMember> miembros,
    required String emptyText,
    required TextEditingController searchCtrl,
    required List<Map<String, dynamic>> resultados,
    required ValueChanged<String> onSearch,
    required String searchHint,
    required ValueChanged<Map<String, dynamic>> onAdd,
    required ValueChanged<FamilyMember> onRemove,
  }) {
    return [
      _roleHeader(titulo, miembros.length, icono, color),
      _sectionHint(hint),
      const SizedBox(height: 8),
      if (miembros.isEmpty)
        _emptyRow(emptyText)
      else
        ...miembros.map(
          (m) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icono, size: 16, color: color),
              ),
              title: Text(
                m.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              // El rol siempre visible, para que no haya duda de en qué
              // sección está cada persona.
              subtitle: Text(
                m.matricula != null
                    ? '${m.roleLabel} · Matrícula ${m.matricula}'
                    : m.roleLabel,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                tooltip: 'Quitar de la familia',
                onPressed: () => onRemove(m),
              ),
            ),
          ),
        ),
      const SizedBox(height: 8),
      TextField(
        controller: searchCtrl,
        onChanged: onSearch,
        decoration: _inputDeco(searchHint, Icons.person_add),
      ),
      if (resultados.isNotEmpty) ...[
        const SizedBox(height: 4),
        Card(
          elevation: 3,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: resultados.length,
              itemBuilder: (_, i) {
                final u = resultados[i];
                final mat = u['Matricula'] ?? u['matricula'];
                final emp = u['NumEmpleado'] ?? u['num_empleado'];
                final sub = mat != null
                    ? 'Matrícula: $mat'
                    : (emp != null ? 'No. empleado: $emp' : null);
                return ListTile(
                  dense: true,
                  leading: Icon(icono, color: color),
                  title: Text(_userName(u)),
                  subtitle: sub != null
                      ? Text(sub, style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.green,
                    ),
                    onPressed: () => onAdd(u),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ];
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _navy),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _navy, width: 2),
    ),
  );

  Widget _buildPersonSearch({
    required TextEditingController controller,
    required List<Map<String, dynamic>> results,
    required Map<String, dynamic>? selected,
    required ValueChanged<String> onChanged,
    required ValueChanged<Map<String, dynamic>> onSelect,
    required VoidCallback onClear,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: hint,
            prefixIcon: Icon(icon, color: _navy),
            suffixIcon: selected != null
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: onClear,
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _navy, width: 2),
            ),
            filled: selected != null,
            fillColor: selected != null ? Colors.blue.shade50 : null,
          ),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 4),
          Card(
            elevation: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final u = results[i];
                  final emp = u['NumEmpleado'] ?? u['num_empleado'];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person),
                    title: Text(_userName(u)),
                    subtitle: emp != null
                        ? Text(
                            'Empleado: $emp',
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                    onTap: () => onSelect(u),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
