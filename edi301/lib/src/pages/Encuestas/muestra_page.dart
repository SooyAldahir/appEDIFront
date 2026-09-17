import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:edi301/core/api_error.dart';
import 'package:edi301/services/encuestas_api.dart';
import 'package:edi301/services/poblacion_api.dart';

/// Sorteo de la muestra de una encuesta.
///
/// Al sortear, la encuesta pasa a audiencia MUESTRA: solo las personas
/// sorteadas la ven y pueden responderla. Eso es lo que hace que el estudio
/// sea representativo — si cualquiera pudiera entrar, los resultados serían
/// de quien se animó a contestar, no de una muestra aleatoria.
class MuestraEncuestaPage extends StatefulWidget {
  final int idEncuesta;
  final String titulo;
  const MuestraEncuestaPage({
    super.key,
    required this.idEncuesta,
    required this.titulo,
  });

  @override
  State<MuestraEncuestaPage> createState() => _MuestraEncuestaPageState();
}

class _MuestraEncuestaPageState extends State<MuestraEncuestaPage> {
  static const _primary = Color(0xFF13436B);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final _encuestas = EncuestasApi();
  final _poblacion = PoblacionApi();

  final _tamanoCtrl = TextEditingController(text: '100');
  final _padresCtrl = TextEditingController();
  final _hijosCtrl = TextEditingController();
  final _semillaCtrl = TextEditingController();

  bool _porCuotas = false;
  bool _incluirColivi = false;

  bool _cargando = true;
  bool _sorteando = false;
  String? _error;

  Map<String, dynamic>? _censo;
  Map<String, dynamic>? _muestra;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _tamanoCtrl.dispose();
    _padresCtrl.dispose();
    _hijosCtrl.dispose();
    _semillaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final censo = await _poblacion.resumen();
      Map<String, dynamic>? muestra;
      try {
        muestra = await _encuestas.verMuestra(widget.idEncuesta);
        if (_entero(muestra['total_muestra']) == 0) muestra = null;
      } catch (_) {
        // Todavía no tiene muestra: es lo normal la primera vez.
      }
      if (!mounted) return;
      setState(() {
        _censo = censo;
        _muestra = muestra;
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

  int get _padresDisponibles =>
      _entero(_mapa(_censo?['totales'])['padres']);
  int get _hijosDisponibles => _entero(_mapa(_censo?['totales'])['hijos']);
  int get _elegibles => _padresDisponibles + _hijosDisponibles;

  Future<void> _sortear() async {
    final rehacer = _muestra != null;

    final cuerpo = <String, dynamic>{
      'incluir_colivi': _incluirColivi,
      if (_semillaCtrl.text.trim().isNotEmpty) 'semilla': _semillaCtrl.text.trim(),
      if (rehacer) 'reemplazar': true,
    };

    if (_porCuotas) {
      final p = int.tryParse(_padresCtrl.text.trim()) ?? 0;
      final h = int.tryParse(_hijosCtrl.text.trim()) ?? 0;
      if (p + h == 0) {
        _aviso('Indica cuántos padres y cuántos hijos quieres.', error: true);
        return;
      }
      cuerpo['cuotas'] = {'PADRES': p, 'HIJOS': h};
    } else {
      final n = int.tryParse(_tamanoCtrl.text.trim()) ?? 0;
      if (n <= 0) {
        _aviso('Indica el tamaño de la muestra.', error: true);
        return;
      }
      cuerpo['tamano'] = n;
    }

    if (!await _confirmar(rehacer)) return;

    setState(() => _sorteando = true);
    try {
      await _encuestas.sortearMuestra(widget.idEncuesta, cuerpo);
      await _cargar();
      if (mounted) _aviso('Muestra sorteada');
    } catch (e) {
      _aviso(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sorteando = false);
    }
  }

  Future<bool> _confirmar(bool rehacer) async {
    final respuestas = _entero(_muestra?['respuestas_recibidas']);
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(rehacer ? '¿Volver a sortear?' : '¿Sortear la muestra?'),
        content: Text(
          rehacer
              ? (respuestas > 0
                  ? 'Esta encuesta ya tiene $respuestas respuesta(s). Si '
                      'vuelves a sortear, esas respuestas dejarán de '
                      'corresponder a la muestra y el estudio pierde validez.'
                  : 'Se reemplazará la muestra actual por una nueva.')
              : 'A partir de ahora solo las personas sorteadas podrán ver y '
                  'responder esta encuesta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              rehacer ? 'Volver a sortear' : 'Sortear',
              style: TextStyle(color: rehacer ? Colors.red : _primary),
            ),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _quitar() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Abrir a todos?'),
        content: const Text(
          'Se borra la muestra y la encuesta vuelve a estar disponible para '
          'todos los usuarios.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir a todos',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (r != true) return;

    setState(() => _sorteando = true);
    try {
      await _encuestas.quitarMuestra(widget.idEncuesta);
      await _cargar();
      if (mounted) _aviso('La encuesta quedó abierta a todos');
    } catch (e) {
      _aviso(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sorteando = false);
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Muestra'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(
                      widget.titulo,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (_muestra != null) ...[
                      _muestraActual(),
                      const SizedBox(height: 20),
                    ],
                    _poblacionDisponible(),
                    const SizedBox(height: 20),
                    _configuracion(),
                    const SizedBox(height: 20),
                    _botonSortear(),
                    if (_muestra != null) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _sorteando ? null : _quitar,
                        icon: const Icon(Icons.lock_open, size: 18),
                        label: const Text('Quitar la muestra y abrir a todos'),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _muestraActual() {
    final m = _muestra!;
    final estratos = _listaMapas(m['estratos']);
    final recibidas = _entero(m['respuestas_recibidas']);
    final total = _entero(m['total_muestra']);
    final tasa = (m['tasa_respuesta_pct'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined,
                  size: 18, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Text('Muestra activa',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const Spacer(),
              Text('$total personas',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ...estratos.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(_grupo('${e['estrato']}'),
                            style: const TextStyle(fontSize: 13))),
                    Text('${_entero(e['total'])}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Respuestas recibidas',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
              ),
              Text('$recibidas de $total  (${tasa.toStringAsFixed(0)}%)',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          if (m['semilla'] != null) ...[
            const SizedBox(height: 10),
            // La semilla permite volver a generar exactamente esta muestra.
            // Conviene anotarla en la metodología del estudio.
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: '${m['semilla']}'));
                _aviso('Semilla copiada');
              },
              child: Row(
                children: [
                  Icon(Icons.key_outlined,
                      size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Semilla: ${m['semilla']}',
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.grey.shade700),
                    ),
                  ),
                  Icon(Icons.copy, size: 13, color: Colors.grey.shade600),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _poblacionDisponible() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Población disponible',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: _primary)),
            const SizedBox(height: 4),
            Text(
              _incluirColivi
                  ? 'Incluyendo alumnos de COLIVI.'
                  : 'Sin alumnos de COLIVI.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _renglon('Padres', _padresDisponibles),
            _renglon('Hijos', _hijosDisponibles),
            const Divider(height: 18),
            _renglon('Total', _elegibles, negrita: true),
          ],
        ),
      );

  Widget _renglon(String etiqueta, int valor, {bool negrita = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
                child: Text(etiqueta,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            negrita ? FontWeight.bold : FontWeight.normal))),
            Text('$valor',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        negrita ? FontWeight.bold : FontWeight.w600)),
          ],
        ),
      );

  Widget _configuracion() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cómo sortear',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: _primary)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Por total')),
                ButtonSegment(value: true, label: Text('Por cuotas')),
              ],
              selected: {_porCuotas},
              onSelectionChanged: (s) =>
                  setState(() => _porCuotas = s.first),
            ),
            const SizedBox(height: 14),
            if (!_porCuotas) ...[
              TextField(
                controller: _tamanoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Tamaño de la muestra',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                _previewProporcional(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _padresCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Padres',
                        helperText: 'máx. $_padresDisponibles',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hijosCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Hijos',
                        helperText: 'máx. $_hijosDisponibles',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Incluir alumnos de COLIVI',
                  style: TextStyle(fontSize: 14)),
              value: _incluirColivi,
              activeThumbColor: _primary,
              onChanged: (v) => setState(() => _incluirColivi = v),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Opciones avanzadas',
                  style: TextStyle(fontSize: 14)),
              children: [
                TextField(
                  controller: _semillaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Semilla (opcional)',
                    helperText:
                        'Con la misma semilla y la misma población, el sorteo '
                        'da exactamente la misma muestra. Sirve para '
                        'documentar la metodología.',
                    helperMaxLines: 4,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  /// Muestra cómo quedaría repartido el total antes de sortear.
  String _previewProporcional() {
    final n = int.tryParse(_tamanoCtrl.text.trim()) ?? 0;
    if (n <= 0 || _elegibles == 0) return '';
    if (n >= _elegibles) return 'Se invitaría a toda la población elegible.';
    // Mismo reparto proporcional que hace el servidor (restos mayores).
    final exactoPadres = _padresDisponibles * n / _elegibles;
    var padres = exactoPadres.floor();
    var hijos = (_hijosDisponibles * n / _elegibles).floor();
    var faltan = n - padres - hijos;
    if (faltan > 0) {
      // La unidad sobrante va al grupo con mayor fracción pendiente.
      final fracPadres = exactoPadres - padres;
      final fracHijos = (_hijosDisponibles * n / _elegibles) - hijos;
      if (fracPadres >= fracHijos) {
        padres += faltan;
      } else {
        hijos += faltan;
      }
    }
    return 'Quedaría en aproximadamente $padres padres y $hijos hijos, '
        'respetando la proporción real.';
  }

  Widget _botonSortear() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _muestra == null ? _primary : _gold,
            foregroundColor: _muestra == null ? Colors.white : Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: _sorteando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.shuffle),
          label: Text(
            _sorteando
                ? 'Sorteando...'
                : _muestra == null
                    ? 'Sortear muestra'
                    : 'Volver a sortear',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          onPressed: _sorteando ? null : _sortear,
        ),
      );

  String _grupo(String estrato) {
    if (estrato == 'PADRES') return 'Padres';
    if (estrato == 'HIJOS') return 'Hijos';
    return estrato;
  }

  Map<String, dynamic> _mapa(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  List<Map<String, dynamic>> _listaMapas(dynamic v) => v is! List
      ? const []
      : v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  int _entero(dynamic v) => (v as num?)?.toInt() ?? 0;
}
