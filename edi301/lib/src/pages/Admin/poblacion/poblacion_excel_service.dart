import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Exporta el censo de usuarios a .xlsx. Mismo patrón que el resto de
/// reportes: se arma en la app, se guarda en temporales y se abre.
///
/// Recibe el JSON de /api/poblacion tal cual, para que el archivo y la
/// pantalla no puedan discrepar.
class PoblacionExcelService {
  Future<String> exportar(Map<String, dynamic> data) async {
    final totales = _mapa(data['totales']);
    final prop = _mapa(data['proporcion']);
    final criterio = _mapa(data['criterio']);
    final roles = _lista(data['desglose_roles']);
    final colivi = _lista(data['colivi_por_carrera']);

    final excel = Excel.createExcel();
    final porDefecto = excel.getDefaultSheet();

    _hojaResumen(excel, totales, prop, criterio);
    _hojaRoles(excel, roles);
    _hojaColivi(excel, colivi);

    if (porDefecto != null && !_nuestras.contains(porDefecto)) {
      try {
        excel.delete(porDefecto);
      } catch (_) {}
    }

    final bytes = excel.save();
    if (bytes == null) throw Exception('No se pudo generar el archivo.');

    final dir = await getTemporaryDirectory();
    final sello = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final archivo = File('${dir.path}/poblacion_usuarios_$sello.xlsx');
    await archivo.writeAsBytes(bytes, flush: true);

    await OpenFile.open(archivo.path);
    return archivo.path;
  }

  static const _nuestras = ['Resumen', 'Por rol', 'COLIVI excluidos'];

  void _hojaResumen(
    Excel excel,
    Map<String, dynamic> totales,
    Map<String, dynamic> prop,
    Map<String, dynamic> criterio,
  ) {
    final hoja = excel['Resumen'];
    hoja.setColumnWidth(0, 34);
    hoja.setColumnWidth(1, 18);
    hoja.setColumnWidth(2, 14);

    void titulo(String t) {
      hoja.appendRow([TextCellValue(t)]);
      _negrita(hoja, hoja.maxRows - 1, 0);
    }

    void fila(String etiqueta, dynamic valor, [String? extra]) {
      hoja.appendRow([
        TextCellValue(etiqueta),
        valor is num ? IntCellValue(valor.toInt()) : TextCellValue('$valor'),
        if (extra != null) TextCellValue(extra),
      ]);
    }

    titulo('Población de usuarios de la app');
    hoja.appendRow([TextCellValue('')]);
    fila('Generado', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()));
    hoja.appendRow([TextCellValue('')]);

    final padres = _entero(totales['padres']);
    final hijos = _entero(totales['hijos']);

    titulo('Población del estudio');
    fila('Padres', padres, '${_num(prop['padres_pct'])}%');
    fila('Hijos', hijos, '${_num(prop['hijos_pct'])}%');
    fila('Total elegibles', _entero(totales['elegibles']), '100%');
    fila('Hijos por cada padre', '${_num(prop['hijos_por_padre'])}');
    hoja.appendRow([TextCellValue('')]);

    titulo('Excluidos');
    fila('Alumnos de COLIVI', _entero(totales['colivi_excluidos']));
    fila('Otros roles (Admin, etc.)', _entero(totales['otros_roles']));
    fila('Total de cuentas activas', _entero(totales['usuarios_activos']));
    hoja.appendRow([TextCellValue('')]);

    titulo('Criterios usados');
    fila('Se identifica COLIVI por', '${criterio['definicion_colivi'] ?? ''}');
    fila('Roles contados como padres',
        (criterio['roles_padres'] as List?)?.join(', ') ?? '');
    fila('Roles contados como hijos',
        (criterio['roles_hijos'] as List?)?.join(', ') ?? '');
    hoja.appendRow([TextCellValue('')]);
    hoja.appendRow([TextCellValue('${criterio['nota'] ?? ''}')]);
  }

  void _hojaRoles(Excel excel, List<Map<String, dynamic>> roles) {
    final hoja = excel['Por rol'];
    hoja.setColumnWidth(0, 24);
    hoja.setColumnWidth(1, 20);
    hoja.setColumnWidth(2, 14);
    hoja.setColumnWidth(3, 14);
    hoja.setColumnWidth(4, 14);

    _encabezado(hoja, ['Rol', 'Grupo', 'Elegibles', 'COLIVI', 'Total']);
    for (final r in roles) {
      hoja.appendRow([
        TextCellValue('${r['nombre_rol'] ?? ''}'),
        TextCellValue(_grupo('${r['estrato'] ?? ''}')),
        IntCellValue(_entero(r['elegibles'])),
        IntCellValue(_entero(r['colivi'])),
        IntCellValue(_entero(r['total'])),
      ]);
    }
    if (roles.isEmpty) {
      hoja.appendRow([TextCellValue('Sin datos.')]);
    }
  }

  void _hojaColivi(Excel excel, List<Map<String, dynamic>> colivi) {
    final hoja = excel['COLIVI excluidos'];
    hoja.setColumnWidth(0, 50);
    hoja.setColumnWidth(1, 12);

    _encabezado(hoja, ['Carrera', 'Total']);
    for (final c in colivi) {
      hoja.appendRow([
        TextCellValue('${c['carrera'] ?? ''}'),
        IntCellValue(_entero(c['total'])),
      ]);
    }
    if (colivi.isEmpty) {
      hoja.appendRow([TextCellValue('Ningún usuario activo coincide con COLIVI.')]);
    }
  }

  // ── Utilidades ──────────────────────────────────────────────────────────

  void _encabezado(Sheet hoja, List<String> titulos) {
    hoja.appendRow(titulos.map((t) => TextCellValue(t)).toList());
    for (var c = 0; c < titulos.length; c++) {
      _negrita(hoja, 0, c);
    }
  }

  void _negrita(Sheet hoja, int fila, int columna) {
    hoja
        .cell(CellIndex.indexByColumnRow(columnIndex: columna, rowIndex: fila))
        .cellStyle = CellStyle(bold: true);
  }

  String _grupo(String estrato) {
    if (estrato == 'PADRES') return 'Padres';
    if (estrato == 'HIJOS') return 'Hijos';
    return 'Fuera del estudio';
  }

  Map<String, dynamic> _mapa(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  List<Map<String, dynamic>> _lista(dynamic v) => v is! List
      ? const []
      : v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  int _entero(dynamic v) => (v as num?)?.toInt() ?? 0;
  String _num(dynamic v) => v == null ? '—' : '$v';
}
