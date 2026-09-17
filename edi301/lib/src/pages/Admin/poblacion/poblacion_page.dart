import 'package:flutter/material.dart';

import 'package:edi301/core/api_error.dart';
import 'package:edi301/services/poblacion_api.dart';
import 'package:edi301/src/pages/Admin/poblacion/poblacion_excel_service.dart';

/// Cuántos usuarios hay en la app, separados en padres e hijos y sin los
/// alumnos de COLIVI. Es el insumo para decidir el tamaño de una muestra.
class PoblacionPage extends StatefulWidget {
  const PoblacionPage({super.key});

  @override
  State<PoblacionPage> createState() => _PoblacionPageState();
}

class _PoblacionPageState extends State<PoblacionPage> {
  static const _primary = Color(0xFF13436B);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final _api = PoblacionApi();
  late Future<Map<String, dynamic>> _future;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _future = _api.resumen();
  }

  Future<void> _exportar(Map<String, dynamic> data) async {
    setState(() => _exportando = true);
    try {
      await PoblacionExcelService().exportar(data);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Población de usuarios'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(friendlyError(snap.error!),
                    textAlign: TextAlign.center),
              ),
            );
          }

          final data = snap.data!;
          final totales = Map<String, dynamic>.from(data['totales'] as Map);
          final prop = Map<String, dynamic>.from(data['proporcion'] as Map);
          final roles = (data['desglose_roles'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final colivi = (data['colivi_por_carrera'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          final padres = _int(totales['padres']);
          final hijos = _int(totales['hijos']);
          final elegibles = _int(totales['elegibles']);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _api.resumen());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _tarjetaTotal(elegibles),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _tarjeta('Padres', padres,
                        _double(prop['padres_pct']), const Color(0xFF00695C))),
                    const SizedBox(width: 12),
                    Expanded(child: _tarjeta('Hijos', hijos,
                        _double(prop['hijos_pct']), const Color(0xFF4527A0))),
                  ],
                ),
                const SizedBox(height: 12),
                _barraProporcion(padres, hijos),
                const SizedBox(height: 20),
                _excluidos(totales),
                const SizedBox(height: 20),
                _tablaRoles(roles),
                if (colivi.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _tablaColivi(colivi),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: _exportando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.file_download_outlined),
                    label: Text(
                      _exportando ? 'Generando...' : 'Exportar a Excel',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _exportando ? null : () => _exportar(data),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Piezas ──────────────────────────────────────────────────────────────

  Widget _tarjetaTotal(int elegibles) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, Color(0xFF0B2B45)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '$elegibles',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'usuarios elegibles para el estudio',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _tarjeta(String titulo, int valor, double pct, Color color) =>
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
            Text(titulo.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text('$valor',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, height: 1.1)),
            Text('${pct.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      );

  /// Una sola barra apilada dice la proporción más rápido que dos números.
  Widget _barraProporcion(int padres, int hijos) {
    final total = padres + hijos;
    if (total == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(flex: padres, child: Container(color: const Color(0xFF00695C))),
                Expanded(flex: hijos, child: Container(color: const Color(0xFF4527A0))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          padres == 0
              ? 'Sin padres registrados'
              : '${(hijos / padres).toStringAsFixed(2)} hijos por cada padre',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _excluidos(Map<String, dynamic> totales) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_outlined,
                    size: 18, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Text('Fuera del conteo',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900)),
              ],
            ),
            const SizedBox(height: 8),
            _renglon('Alumnos de COLIVI', _int(totales['colivi_excluidos'])),
            _renglon('Otros roles (Admin, etc.)', _int(totales['otros_roles'])),
            const Divider(height: 18),
            _renglon('Total de cuentas activas',
                _int(totales['usuarios_activos']), negrita: true),
          ],
        ),
      );

  Widget _renglon(String etiqueta, int valor, {bool negrita = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(etiqueta,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: negrita ? FontWeight.bold : FontWeight.normal)),
            ),
            Text('$valor',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: negrita ? FontWeight.bold : FontWeight.w600)),
          ],
        ),
      );

  Widget _tablaRoles(List<Map<String, dynamic>> roles) => _bloque(
        'Desglose por rol',
        'Sirve para revisar la clasificación: si un rol quedó en el grupo '
            'equivocado, se ve aquí.',
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.4),
          },
          children: [
            _encabezadoTabla(['Rol', 'Grupo', 'Elegibles', 'COLIVI']),
            ...roles.map((r) => TableRow(children: [
                  _celda(r['nombre_rol']?.toString() ?? ''),
                  _celda(_grupoLegible(r['estrato']?.toString())),
                  _celda('${_int(r['elegibles'])}', alineado: true),
                  _celda('${_int(r['colivi'])}', alineado: true),
                ])),
          ],
        ),
      );

  Widget _tablaColivi(List<Map<String, dynamic>> colivi) => _bloque(
        'Carreras contadas como COLIVI',
        'Se identifican por el campo "carrera". Si falta alguna, hay que '
            'corregir ese dato en los perfiles.',
        Table(
          columnWidths: const {0: FlexColumnWidth(4), 1: FlexColumnWidth(1)},
          children: [
            _encabezadoTabla(['Carrera', 'Total']),
            ...colivi.map((c) => TableRow(children: [
                  _celda(c['carrera']?.toString() ?? ''),
                  _celda('${_int(c['total'])}', alineado: true),
                ])),
          ],
        ),
      );

  Widget _bloque(String titulo, String nota, Widget contenido) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _primary)),
            const SizedBox(height: 4),
            Text(nota,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            contenido,
          ],
        ),
      );

  TableRow _encabezadoTabla(List<String> titulos) => TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade100),
        children: titulos
            .map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  child: Text(t,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ))
            .toList(),
      );

  Widget _celda(String texto, {bool alineado = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 13),
          textAlign: alineado ? TextAlign.right : TextAlign.left,
        ),
      );

  String _grupoLegible(String? estrato) {
    switch (estrato) {
      case 'PADRES':
        return 'Padres';
      case 'HIJOS':
        return 'Hijos';
      default:
        return 'Fuera del estudio';
    }
  }

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
  double _double(dynamic v) => (v as num?)?.toDouble() ?? 0;
}
