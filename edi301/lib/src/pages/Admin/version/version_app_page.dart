import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

/// Publica la versión nueva sin tocar la base de datos a mano.
///
/// Dos números por plataforma:
/// - **publicada**: hay algo más nuevo. Sugiere, se puede posponer 24 h.
/// - **mínima**: por debajo, la app bloquea. Se deja vacía salvo que una
///   versión vieja de verdad ya no funcione contra el backend.
class VersionAppPage extends StatefulWidget {
  const VersionAppPage({super.key});

  @override
  State<VersionAppPage> createState() => _VersionAppPageState();
}

class _VersionAppPageState extends State<VersionAppPage> {
  static const _primary = Color(0xFF13436B);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final ApiHttp _http = ApiHttp();

  final _ctrls = <String, TextEditingController>{
    'android_publicada': TextEditingController(),
    'android_minima': TextEditingController(),
    'android_url': TextEditingController(),
    'ios_publicada': TextEditingController(),
    'ios_minima': TextEditingController(),
    'ios_url': TextEditingController(),
    'notas': TextEditingController(),
  };

  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  String _versionDeEsteDispositivo = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final info = await PackageInfo.fromPlatform();
      final res = await _http.getJson('/api/app-version/config');
      if (res.statusCode >= 400) throw Exception(parseHttpError(res));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final android = _mapa(data['android']);
      final ios = _mapa(data['ios']);

      _ctrls['android_publicada']!.text = _txt(android['version_publicada']);
      _ctrls['android_minima']!.text = _txt(android['version_minima']);
      _ctrls['android_url']!.text = _txt(android['url_tienda']);
      _ctrls['ios_publicada']!.text = _txt(ios['version_publicada']);
      _ctrls['ios_minima']!.text = _txt(ios['version_minima']);
      _ctrls['ios_url']!.text = _txt(ios['url_tienda']);
      _ctrls['notas']!.text = _txt(data['notas']);

      if (!mounted) return;
      setState(() {
        _versionDeEsteDispositivo = info.version;
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

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final res = await _http.putJson(
        '/api/app-version/config',
        data: {
          'android': {
            'version_publicada': _ctrls['android_publicada']!.text.trim(),
            'version_minima': _ctrls['android_minima']!.text.trim(),
            'url_tienda': _ctrls['android_url']!.text.trim(),
          },
          'ios': {
            'version_publicada': _ctrls['ios_publicada']!.text.trim(),
            'version_minima': _ctrls['ios_minima']!.text.trim(),
            'url_tienda': _ctrls['ios_url']!.text.trim(),
          },
          'notas': _ctrls['notas']!.text.trim(),
        },
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _aviso('Configuración guardada');
      } else {
        _aviso((data['error'] ?? 'No se pudo guardar').toString(), error: true);
      }
    } catch (e) {
      _aviso(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Versión de la app'),
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
                    _explicacion(),
                    const SizedBox(height: 20),
                    _plataforma(
                      'Android',
                      Icons.android,
                      const Color(0xFF00695C),
                      'android',
                      'https://play.google.com/store/apps/details?id=...',
                    ),
                    const SizedBox(height: 16),
                    _plataforma(
                      'iOS',
                      Icons.phone_iphone,
                      const Color(0xFF4527A0),
                      'ios',
                      'https://apps.apple.com/app/id...',
                    ),
                    const SizedBox(height: 16),
                    _notas(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _guardando ? null : _guardar,
                        child: _guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Guardar',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _explicacion() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuando publiques una versión en las tiendas, pon aquí su número '
              'y la app empezará a avisarle a quien tenga una anterior.',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
            ),
            if (_versionDeEsteDispositivo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Este dispositivo tiene la $_versionDeEsteDispositivo',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      );

  Widget _plataforma(
    String titulo,
    IconData icono,
    Color color,
    String prefijo,
    String ejemploUrl,
  ) =>
      Container(
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
                Icon(icono, size: 20, color: color),
                const SizedBox(width: 8),
                Text(titulo,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrls['${prefijo}_publicada'],
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Versión publicada',
                      hintText: '1.2.0',
                      helperText: 'Sugiere actualizar',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ctrls['${prefijo}_minima'],
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Versión mínima',
                      hintText: 'vacío',
                      helperText: 'Bloquea',
                      helperStyle: TextStyle(color: Colors.red),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrls['${prefijo}_url'],
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Enlace a la tienda',
                hintText: ejemploUrl,
                helperText: 'Sin enlace, no se muestra ningún aviso.',
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      );

  Widget _notas() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Qué trae la nueva versión',
                style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
            const SizedBox(height: 4),
            Text(
              'Opcional. Se muestra dentro del aviso, así que conviene una o '
              'dos líneas, no una lista de cambios técnicos.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrls['notas'],
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ahora puedes entrar con huella y ver las '
                    'felicitaciones de cumpleaños con foto.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La versión mínima bloquea la app por completo. Úsala '
                      'solo cuando una versión vieja de verdad ya no funcione '
                      'contra el servidor, y nunca antes de que la nueva esté '
                      'disponible en la tienda.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Map<String, dynamic> _mapa(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  String _txt(dynamic v) => v == null ? '' : v.toString();
}
