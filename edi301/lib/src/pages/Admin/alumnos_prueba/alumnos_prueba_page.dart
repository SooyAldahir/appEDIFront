import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:edi301/core/api_error.dart';
import 'package:edi301/services/alumnos_prueba_api.dart';

/// Alumnos en periodo de prueba.
///
/// El problema que resuelve no es dar de alta —eso es un formulario— sino lo
/// que pasa después: la oficina contó que los alumnos no vuelven a pasar por
/// sistemas cuando les asignan su matrícula. Por eso la pantalla abre en la
/// lista de seguimiento, con los más atrasados arriba, y no en el formulario.
class AlumnosPruebaPage extends StatefulWidget {
  const AlumnosPruebaPage({super.key});

  @override
  State<AlumnosPruebaPage> createState() => _AlumnosPruebaPageState();
}

class _AlumnosPruebaPageState extends State<AlumnosPruebaPage> {
  static const _navy = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final _api = AlumnosPruebaApi();

  ListaPrueba? _lista;
  List<Map<String, dynamic>> _duplicados = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _api.lista();
      // Los duplicados son un extra: si esa consulta falla, la lista principal
      // igual se muestra.
      List<Map<String, dynamic>> dup = const [];
      try {
        dup = await _api.duplicados();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _lista = lista;
        _duplicados = dup;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _cargando = false;
      });
    }
  }

  void _aviso(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _lista;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Alumnos en periodo de prueba'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: _gold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              const Tab(text: 'Seguimiento'),
              Tab(
                text: _duplicados.isEmpty
                    ? 'Duplicados'
                    : 'Duplicados (${_duplicados.length})',
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          onPressed: _abrirAlta,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Agregar'),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _pantallaError()
                : TabBarView(
                    children: [
                      _tabSeguimiento(lista!),
                      _tabDuplicados(),
                    ],
                  ),
      ),
    );
  }

  Widget _pantallaError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );

  // ───────────────────────── Seguimiento ─────────────────────────

  Widget _tabSeguimiento(ListaPrueba lista) {
    if (lista.alumnos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.check_circle_outline, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No hay alumnos en periodo de prueba.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _resumen(lista),
          const SizedBox(height: 16),
          ...lista.alumnos.map(_tarjetaAlumno),
        ],
      ),
    );
  }

  Widget _resumen(ListaPrueba lista) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _dato('En prueba', '${lista.total}', _navy),
                const SizedBox(width: 12),
                _dato(
                  'Pasados de ${lista.diasPeriodo} días',
                  '${lista.vencidos}',
                  lista.vencidos > 0 ? Colors.red.shade700 : Colors.grey,
                ),
              ],
            ),
            if (lista.vencidos > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Los que pasaron el periodo probablemente ya tienen matrícula '
                'y no han vuelto a sistemas. También pueden promoverse solos '
                'desde su perfil en la app.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _dato(String etiqueta, String valor, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            Text(etiqueta,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _tarjetaAlumno(AlumnoPrueba a) {
    final color = a.vencido ? Colors.red.shade700 : _navy;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a.vencido ? Colors.red.shade200 : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Text(
            '${a.dias}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        title: Text(a.nombreCompleto,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((a.correoPersonal ?? '').isNotEmpty)
              Text(a.correoPersonal!, style: const TextStyle(fontSize: 12)),
            Text(
              [
                a.vencido ? 'Pasó el periodo' : '${a.dias} días',
                if ((a.nombreFamilia ?? '').isNotEmpty) a.nombreFamilia!,
                if (!a.activo) 'Cuenta desactivada',
              ].join(' · '),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _abrirPromocion(a),
          child: const Text('Promover'),
        ),
      ),
    );
  }

  // ───────────────────────── Duplicados ─────────────────────────

  Widget _tabDuplicados() {
    if (_duplicados.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.verified_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Nadie con cuenta a prueba comparte nombre con una cuenta '
                  'ya matriculada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              'Estas personas tienen una cuenta a prueba Y otra con matrícula, '
              'a nombre igual. Lo más probable es que se registraran de nuevo '
              'en vez de promover la que ya tenían. Revisa cuál conserva la '
              'familia antes de desactivar ninguna: pueden ser dos personas '
              'que se llaman igual.',
              style: TextStyle(
                  fontSize: 12, color: Colors.amber.shade900, height: 1.35),
            ),
          ),
          const SizedBox(height: 14),
          ..._duplicados.map(_tarjetaDuplicado),
        ],
      ),
    );
  }

  Widget _tarjetaDuplicado(Map<String, dynamic> d) {
    final nombre = '${d['nombre'] ?? ''} ${d['apellido'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          _filaDup('A prueba', '${d['correo_personal'] ?? '—'}', _navy),
          const SizedBox(height: 4),
          _filaDup(
            'Con matrícula',
            '${d['matricula'] ?? '—'} · ${d['correo_matriculado'] ?? '—'}',
            Colors.green.shade800,
          ),
        ],
      ),
    );
  }

  Widget _filaDup(String etiqueta, String valor, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(etiqueta,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 12))),
        ],
      );

  // ───────────────────────── Alta ─────────────────────────

  Future<void> _abrirAlta() async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaAlta(api: _api),
    );
    if (creado == true) {
      _aviso('Alumno agregado.', error: false);
      _cargar();
    }
  }

  // ───────────────────────── Promoción ─────────────────────────

  Future<void> _abrirPromocion(AlumnoPrueba a) async {
    final hecho = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoPromocion(api: _api, alumno: a),
    );
    if (hecho == true) {
      _aviso('${a.nombreCompleto} ya tiene matrícula.', error: false);
      _cargar();
    }
  }
}

// ═══════════════════════════ Alta ═══════════════════════════

class _HojaAlta extends StatefulWidget {
  final AlumnosPruebaApi api;
  const _HojaAlta({required this.api});

  @override
  State<_HojaAlta> createState() => _HojaAltaState();
}

class _HojaAltaState extends State<_HojaAlta> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _correo = TextEditingController();
  final _pass = TextEditingController();
  final _telefono = TextEditingController();
  final _carrera = TextEditingController();

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _correo, _pass, _telefono, _carrera]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.api.crear(
        nombre: _nombre.text,
        apellido: _apellido.text,
        correoPersonal: _correo.text,
        contrasena: _pass.text,
        telefono: _telefono.text,
        carrera: _carrera.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Alumno sin matrícula',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Para quien está en el periodo de prueba y todavía no tiene '
                  'matrícula ni correo institucional. Entra a la app con su '
                  'correo personal, y cuando le den su matrícula puede '
                  'completarla él mismo desde su perfil.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                ),
                const SizedBox(height: 18),
                _campo(_nombre, 'Nombre', requerido: true),
                _campo(_apellido, 'Apellido', requerido: true),
                _campo(
                  _correo,
                  'Correo personal',
                  requerido: true,
                  teclado: TextInputType.emailAddress,
                  validador: (v) => (v ?? '').contains('@')
                      ? null
                      : 'Escribe un correo válido',
                  ayuda: 'Es con el que va a entrar a la app.',
                ),
                _campo(
                  _pass,
                  'Contraseña provisional',
                  requerido: true,
                  validador: (v) => (v ?? '').length >= 6
                      ? null
                      : 'Al menos 6 caracteres',
                  ayuda: 'Dísela para que pueda entrar y cambiarla después.',
                ),
                _campo(_telefono, 'Teléfono (opcional)',
                    teclado: TextInputType.phone),
                _campo(_carrera, 'Carrera o área (opcional)'),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Agregar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    bool requerido = false,
    TextInputType? teclado,
    String? Function(String?)? validador,
    String? ayuda,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: teclado,
          decoration: InputDecoration(
            labelText: etiqueta,
            helperText: ayuda,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          validator: (v) {
            if (requerido && (v == null || v.trim().isEmpty)) {
              return 'Obligatorio';
            }
            return validador?.call(v);
          },
        ),
      );
}

// ═══════════════════════════ Promoción ═══════════════════════════

class _DialogoPromocion extends StatefulWidget {
  final AlumnosPruebaApi api;
  final AlumnoPrueba alumno;
  const _DialogoPromocion({required this.api, required this.alumno});

  @override
  State<_DialogoPromocion> createState() => _DialogoPromocionState();
}

class _DialogoPromocionState extends State<_DialogoPromocion> {
  final _matricula = TextEditingController();
  final _correo = TextEditingController();
  final _carrera = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _matricula.dispose();
    _correo.dispose();
    _carrera.dispose();
    super.dispose();
  }

  Future<void> _promover() async {
    final mat = int.tryParse(_matricula.text.trim());
    final correo = _correo.text.trim();
    if (mat == null || mat <= 0) {
      setState(() => _error = 'Escribe una matrícula válida.');
      return;
    }
    if (!correo.contains('@')) {
      setState(() => _error = 'Escribe el correo institucional.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.api.promoverComoAdmin(
        idUsuario: widget.alumno.id,
        matricula: mat,
        correoInstitucional: correo,
        carrera: _carrera.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Promover a ${widget.alumno.nombreCompleto}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le asignas su matrícula y su correo institucional. Su correo '
              'personal no se borra: le sigue sirviendo para entrar.',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _matricula,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Matrícula',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo institucional',
                hintText: 'nombre.apellido@ulv.edu.mx',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _carrera,
              decoration: const InputDecoration(
                labelText: 'Carrera (opcional)',
                helperText: 'Si se deja vacío, conserva la que ya tenía.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _promover,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Promover'),
        ),
      ],
    );
  }
}
