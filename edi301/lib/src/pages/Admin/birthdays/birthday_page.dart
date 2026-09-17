import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:edi301/tools/media_picker.dart';
import 'package:edi301/services/users_api.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/services/chat_api.dart';
import 'package:edi301/src/pages/Chat/chat_page.dart';
import 'package:http/http.dart' as http;
import 'package:edi301/core/api_error.dart';

// ─── Modelo ligero para cumpleañeros ─────────────────────────────────────────
class _Cumpleanero {
  final int idUsuario;
  final String nombre;
  final String apellido;
  final String? fotoPerfil;
  final String? fechaNacimiento;
  final int? diasRestantes; // para próximos
  final int? diasCumplidos; // para pasados

  _Cumpleanero.fromJson(Map<String, dynamic> j)
    : idUsuario = j['id_usuario'] ?? 0,
      nombre = j['nombre'] ?? '',
      apellido = j['apellido'] ?? '',
      fotoPerfil = j['url_foto_perfil'] ?? j['foto_perfil'],
      fechaNacimiento = j['fecha_nacimiento'],
      diasRestantes = j['dias_para_cumple'] as int?,
      diasCumplidos = j['dias_cumplidos'] as int?;

  String get nombreCompleto => '$nombre $apellido'.trim();
}

// ─── BirthdaysPage ────────────────────────────────────────────────────────────
class BirthdaysPage extends StatefulWidget {
  const BirthdaysPage({super.key});
  @override
  State<BirthdaysPage> createState() => _BirthdaysPageState();
}

class _BirthdaysPageState extends State<BirthdaysPage>
    with SingleTickerProviderStateMixin {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final ApiHttp _http = ApiHttp();
  late TabController _tab;

  // Data per tab
  List<_Cumpleanero> _pasados = [];
  List<_Cumpleanero> _hoy = [];
  List<_Cumpleanero> _proximos = [];

  bool _loadingPasados = true;
  bool _loadingHoy = true;
  bool _loadingProximos = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
    _cargar('pasados');
    _cargar('hoy');
    _cargar('proximos');
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cargar(String rango) async {
    try {
      final res = await _http.getJson(
        '/api/usuarios/cumpleanos',
        query: {'rango': rango},
      );
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((j) => _Cumpleanero.fromJson(j))
            .toList();
        if (!mounted) return;
        setState(() {
          if (rango == 'pasados') {
            _pasados = list;
            _loadingPasados = false;
          }
          if (rango == 'hoy') {
            _hoy = list;
            _loadingHoy = false;
          }
          if (rango == 'proximos') {
            _proximos = list;
            _loadingProximos = false;
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (rango == 'pasados') _loadingPasados = false;
        if (rango == 'hoy') _loadingHoy = false;
        if (rango == 'proximos') _loadingProximos = false;
      });
    }
  }

  void _irAlChat(_Cumpleanero u) async {
    final idSala = await ChatApi().initPrivateChat(u.idUsuario);
    if (idSala != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatPage(idSala: idSala, nombreChat: u.nombreCompleto),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cumpleaños 🎂'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configurar felicitación',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _FelicitacionConfigPage(),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Pasados', icon: Icon(Icons.history, size: 18)),
            Tab(text: 'Hoy', icon: Icon(Icons.cake, size: 18)),
            Tab(text: 'Próximos', icon: Icon(Icons.upcoming, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildTab(_pasados, _loadingPasados, 'pasados'),
          _buildTab(_hoy, _loadingHoy, 'hoy'),
          _buildTab(_proximos, _loadingProximos, 'proximos'),
        ],
      ),
    );
  }

  Widget _buildTab(List<_Cumpleanero> lista, bool loading, String rango) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cake_outlined,
              size: 72,
              color: rango == 'hoy' ? Colors.pink[200] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              rango == 'pasados'
                  ? 'Sin cumpleaños recientes.'
                  : rango == 'hoy'
                  ? 'Hoy no hay cumpleaños. 🎈'
                  : 'No hay próximos cumpleaños.',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(rango),
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: lista.length,
        itemBuilder: (_, i) => _buildCard(lista[i], rango),
      ),
    );
  }

  Widget _buildCard(_Cumpleanero u, String rango) {
    final isHoy = rango == 'hoy';
    final isPasado = rango == 'pasados';
    final isProximo = rango == 'proximos';

    Color borderColor;
    Color bgColor;
    String badge;

    if (isHoy) {
      borderColor = Colors.pinkAccent;
      bgColor = Colors.pink.shade50;
      badge = '🎉 ¡Hoy es su cumpleaños!';
    } else if (isPasado) {
      borderColor = Colors.grey.shade400;
      bgColor = Colors.grey.shade50;
      final dias = u.diasCumplidos ?? 0;
      badge = dias == 1 ? 'Cumpleaños ayer 🎂' : 'Hace $dias días 🎂';
    } else {
      borderColor = Colors.blue.shade300;
      bgColor = Colors.blue.shade50;
      final dias = u.diasRestantes ?? 0;
      badge = dias == 1 ? '¡Mañana es su cumpleaños! 🎈' : 'En $dias días 🎈';
    }

    final fotoUrl = u.fotoPerfil != null
        ? (u.fotoPerfil!.startsWith('http')
              ? u.fotoPerfil!
              : '${ApiHttp.baseUrl}${u.fotoPerfil}')
        : null;

    return Card(
      elevation: isHoy ? 5 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: isHoy ? 2 : 1),
      ),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: borderColor.withOpacity(0.2),
              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
              child: fotoUrl == null
                  ? Text(
                      u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 24, color: borderColor),
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.nombreCompleto,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge,
                    style: TextStyle(
                      fontSize: 12,
                      color: borderColor,
                      fontWeight: isHoy ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Chat button (only for today)
            if (isHoy)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.pink),
                tooltip: 'Enviar felicitación',
                onPressed: () => _irAlChat(u),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Pantalla de configuración de la felicitación de cumpleaños ──────────────
// Imagen, título y mensaje. Todo se guarda en el servidor (EDI.App_Config),
// no en memoria: antes la imagen "se quitaba sola" porque su URL vivía en una
// variable del proceso de Node y se perdía en cada reinicio o redeploy.
class _FelicitacionConfigPage extends StatefulWidget {
  const _FelicitacionConfigPage();
  @override
  State<_FelicitacionConfigPage> createState() =>
      _FelicitacionConfigPageState();
}

class _FelicitacionConfigPageState extends State<_FelicitacionConfigPage> {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  // Nombre de muestra para la vista previa.
  static const _demoNombre = 'Ana';
  static const _demoApellido = 'Ramírez';

  static const _variables = <String, String>{
    '{nombre}': 'Nombre de pila',
    '{apellido}': 'Apellido',
    '{nombre_completo}': 'Nombre y apellido',
  };

  final ApiHttp _http = ApiHttp();

  final _tituloCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  final _focoTitulo = FocusNode();
  final _focoMensaje = FocusNode();

  String? _imagenActual;
  String _tituloGuardado = '';
  String _mensajeGuardado = '';

  int _limiteTitulo = 120;
  int _limiteMensaje = 350;

  bool _loading = true;
  bool _uploading = false;
  bool _guardando = false;

  bool get _hayCambios =>
      _tituloCtrl.text.trim() != _tituloGuardado ||
      _mensajeCtrl.text.trim() != _mensajeGuardado;

  @override
  void initState() {
    super.initState();
    // La vista previa se redibuja mientras se escribe.
    _tituloCtrl.addListener(_refrescar);
    _mensajeCtrl.addListener(_refrescar);
    // El foco decide en qué campo se inserta una variable.
    _focoTitulo.addListener(_refrescar);
    _focoMensaje.addListener(_refrescar);
    _cargar();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensajeCtrl.dispose();
    _focoTitulo.dispose();
    _focoMensaje.dispose();
    super.dispose();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  Future<void> _cargar() async {
    try {
      final res = await _http.getJson('/api/usuarios/cumpleanos/config');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _tituloGuardado = (data['titulo'] ?? '').toString();
        _mensajeGuardado = (data['mensaje'] ?? '').toString();
        _tituloCtrl.text = _tituloGuardado;
        _mensajeCtrl.text = _mensajeGuardado;
        _imagenActual = (data['imagen_url'] ?? data['imagen'])?.toString();
        if (_imagenActual != null && _imagenActual!.isEmpty) _imagenActual = null;

        final limites = data['limites'];
        if (limites is Map) {
          _limiteTitulo = (limites['titulo'] as num?)?.toInt() ?? _limiteTitulo;
          _limiteMensaje =
              (limites['mensaje'] as num?)?.toInt() ?? _limiteMensaje;
        }
      }
    } catch (e) {
      _aviso(friendlyError(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Texto ───────────────────────────────────────────────────────────────

  String _render(String plantilla) => plantilla
      .replaceAll('{nombre_completo}', '$_demoNombre $_demoApellido')
      .replaceAll('{nombre}', _demoNombre)
      .replaceAll('{apellido}', _demoApellido);

  TextEditingController get _campoActivo =>
      _focoTitulo.hasFocus ? _tituloCtrl : _mensajeCtrl;

  void _insertarVariable(String variable) {
    final ctrl = _campoActivo;
    final seleccion = ctrl.selection;
    final texto = ctrl.text;
    final inicio = seleccion.isValid ? seleccion.start : texto.length;
    final fin = seleccion.isValid ? seleccion.end : texto.length;

    ctrl.value = TextEditingValue(
      text: texto.replaceRange(inicio, fin, variable),
      selection: TextSelection.collapsed(offset: inicio + variable.length),
    );
  }

  /// Misma regla que valida el servidor. Se comprueba aquí para no gastar un
  /// viaje de red y para poder explicar el porqué.
  String? _validar() {
    final titulo = _tituloCtrl.text.trim();
    final mensaje = _mensajeCtrl.text.trim();

    if (titulo.isEmpty) return 'El título no puede quedar vacío.';
    if (mensaje.isEmpty) return 'El mensaje no puede quedar vacío.';

    final texto = '$titulo $mensaje';
    if (!texto.contains('{nombre}') && !texto.contains('{nombre_completo}')) {
      return 'Incluye {nombre} o {nombre_completo} en el título o el mensaje.';
    }

    final desconocidas = RegExp(r'\{[^{}]*\}')
        .allMatches(texto)
        .map((m) => m.group(0)!)
        .where((v) => !_variables.containsKey(v))
        .toSet();
    if (desconocidas.isNotEmpty) {
      return 'Variable no reconocida: ${desconocidas.join(', ')}';
    }
    return null;
  }

  Future<void> _guardar() async {
    final error = _validar();
    if (error != null) {
      _aviso(error, error: true);
      return;
    }

    setState(() => _guardando = true);
    try {
      final res = await _http.putJson(
        '/api/usuarios/cumpleanos/config',
        data: {
          'titulo': _tituloCtrl.text.trim(),
          'mensaje': _mensajeCtrl.text.trim(),
        },
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _tituloGuardado = (data['titulo'] ?? '').toString();
        _mensajeGuardado = (data['mensaje'] ?? '').toString();
        _aviso('Mensaje guardado');
      } else {
        _aviso((data['error'] ?? 'No se pudo guardar').toString(), error: true);
      }
    } catch (e) {
      _aviso(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Imagen ──────────────────────────────────────────────────────────────

  Future<void> _seleccionarImagen() async {
    final picked = await MediaPicker.pickFromGallery(
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      // Un solo request: sube la imagen y el servidor guarda la URL.
      final streamed = await _http.multipart(
        '/api/usuarios/cumpleanos/imagen',
        method: 'POST',
        files: [await http.MultipartFile.fromPath('imagen', picked.path)],
      );
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final nueva = (data['imagen_url'] ?? data['url'] ?? data['imagen'] ?? '')
            .toString();
        if (nueva.isNotEmpty) setState(() => _imagenActual = nueva);
        _aviso('Imagen actualizada');
      } else {
        _aviso((data['error'] ?? 'Error ${response.statusCode}').toString(),
            error: true);
      }
    } catch (e) {
      _aviso(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _quitarImagen() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar la imagen?'),
        content: const Text(
          'Las felicitaciones se publicarán solo con texto hasta que subas '
          'otra imagen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _uploading = true);
    try {
      final res = await _http.deleteJson('/api/usuarios/cumpleanos/imagen');
      if (res.statusCode == 200) {
        setState(() => _imagenActual = null);
        _aviso('Imagen quitada');
      } else {
        _aviso('No se pudo quitar la imagen', error: true);
      }
    } catch (e) {
      _aviso(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _aviso(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Felicitación de cumpleaños'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _explicacion(),
                const SizedBox(height: 24),
                _seccion('Imagen'),
                const SizedBox(height: 12),
                _bloqueImagen(),
                const SizedBox(height: 28),
                _seccion('Mensaje'),
                const SizedBox(height: 12),
                _campoTitulo(),
                const SizedBox(height: 16),
                _campoMensaje(),
                const SizedBox(height: 12),
                _chipsVariables(),
                const SizedBox(height: 24),
                _vistaPrevia(),
                const SizedBox(height: 28),
                _botonGuardar(),
              ],
            ),
    );
  }

  Widget _seccion(String texto) => Text(
        texto,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _primary,
        ),
      );

  Widget _explicacion() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Así se verá la publicación que el sistema crea automáticamente a '
          'las 8:00 del día del cumpleaños de cada integrante.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );

  Widget _bloqueImagen() {
    final sinImagen = _imagenActual == null || _imagenActual!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.grey.shade100,
          ),
          clipBehavior: Clip.antiAlias,
          child: sinImagen
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Sin imagen',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'La felicitación se publica solo con texto',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : Image.network(
                  _imagenActual!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'La imagen guardada no se pudo cargar.\n'
                          'Sube otra para reemplazarla.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.photo_library),
                label: Text(
                  _uploading
                      ? 'Subiendo...'
                      : (sinImagen ? 'Subir imagen' : 'Cambiar imagen'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _uploading ? null : _seleccionarImagen,
              ),
            ),
            if (!sinImagen) ...[
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Quitar imagen',
                onPressed: _uploading ? null : _quitarImagen,
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade700,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _campoTitulo() => TextField(
        controller: _tituloCtrl,
        focusNode: _focoTitulo,
        maxLength: _limiteTitulo,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Título',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      );

  Widget _campoMensaje() => TextField(
        controller: _mensajeCtrl,
        focusNode: _focoMensaje,
        maxLength: _limiteMensaje,
        maxLines: 5,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Mensaje',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
      );

  Widget _chipsVariables() {
    final enTitulo = _focoTitulo.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toca para insertar en ${enTitulo ? 'el título' : 'el mensaje'}:',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _variables.entries
              .map(
                (e) => ActionChip(
                  label: Text(e.key, style: const TextStyle(fontSize: 12)),
                  tooltip: e.value,
                  backgroundColor: _primary.withValues(alpha: 0.08),
                  side: BorderSide(color: _primary.withValues(alpha: 0.2)),
                  onPressed: () => _insertarVariable(e.key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _vistaPrevia() {
    final sinImagen = _imagenActual == null || _imagenActual!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _seccion('Vista previa'),
            const SizedBox(width: 8),
            Text(
              '(con un nombre de ejemplo)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!sinImagen)
                Image.network(
                  _imagenActual!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _render(_tituloCtrl.text),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _render(_mensajeCtrl.text),
                      style: const TextStyle(fontSize: 14, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botonGuardar() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: (_guardando || !_hayCambios) ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _hayCambios ? 'Guardar mensaje' : 'Sin cambios',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      );
}
