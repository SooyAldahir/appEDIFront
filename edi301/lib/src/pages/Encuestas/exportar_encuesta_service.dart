import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'package:edi301/services/encuestas_api.dart';

/// Genera un .xlsx con los resultados de una encuesta y lo abre con la app
/// que el sistema tenga asociada (Excel, Numbers, Google Sheets…).
///
/// Sigue el mismo patrón que los reportes de familias: el archivo se arma en
/// la app, se guarda en el directorio temporal y se abre con OpenFile.
///
/// Las encuestas son anónimas por diseño: `EDI.Encuesta_Respuestas` solo
/// guarda un HMAC del usuario para impedir el doble voto, y el backend no lo
/// expone. Por eso el archivo nunca dice quién respondió qué; la hoja de
/// detalle numera las respuestas 1..N y nada más.
class ExportarEncuestaService {
  final EncuestasApi _api = EncuestasApi();

  static const _sinResponder = '—';

  /// Devuelve la ruta del archivo generado.
  Future<String> exportar(int idEncuesta) async {
    final data = await _api.results(idEncuesta);

    final titulo = (data['titulo'] ?? 'Encuesta').toString();
    final descripcion = (data['descripcion'] ?? '').toString();
    final estado = (data['estado'] ?? '').toString();
    final fechaLimite = data['fecha_limite']?.toString();
    final total = (data['total_respuestas'] as num?)?.toInt() ?? 0;

    final preguntas = _mapList(data['preguntas']);
    final conteos = _mapList(data['conteos']);
    final libres = _mapList(data['respuestas_libres']);
    final detalle = _mapList(data['detalle']);

    final excel = Excel.createExcel();
    final hojaPorDefecto = excel.getDefaultSheet();

    _hojaResumen(excel, titulo, descripcion, estado, fechaLimite, total,
        preguntas.length);
    _hojaResultados(excel, preguntas, conteos, total);
    _hojaAbiertas(excel, preguntas, libres);
    _hojaDetalle(excel, preguntas, detalle);

    // Excel.createExcel() deja una hoja vacía ('Sheet1'). Se quita al final,
    // cuando ya existen las nuestras: un libro sin hojas no es válido.
    if (hojaPorDefecto != null && !_nuestras.contains(hojaPorDefecto)) {
      try {
        excel.delete(hojaPorDefecto);
      } catch (_) {
        // Si la versión del paquete no deja borrarla, una hoja vacía de más
        // es preferible a no generar el archivo.
      }
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo de Excel.');
    }

    final dir = await getTemporaryDirectory();
    final archivo = File('${dir.path}/${_nombreArchivo(titulo)}');
    await archivo.writeAsBytes(bytes, flush: true);

    await OpenFile.open(archivo.path);
    return archivo.path;
  }

  static const _nuestras = [
    'Resumen',
    'Resultados',
    'Respuestas abiertas',
    'Detalle',
  ];

  // ── Hojas ───────────────────────────────────────────────────────────────

  void _hojaResumen(
    Excel excel,
    String titulo,
    String descripcion,
    String estado,
    String? fechaLimite,
    int total,
    int numPreguntas,
  ) {
    final hoja = excel['Resumen'];
    hoja.setColumnWidth(0, 24);
    hoja.setColumnWidth(1, 60);

    void fila(String etiqueta, String valor) {
      hoja.appendRow([TextCellValue(etiqueta), TextCellValue(valor)]);
      _negrita(hoja, hoja.maxRows - 1, 0);
    }

    hoja.appendRow([TextCellValue('Resultados de la encuesta')]);
    _negrita(hoja, 0, 0);
    hoja.appendRow([TextCellValue('')]);

    fila('Encuesta', titulo);
    if (descripcion.isNotEmpty) fila('Descripción', descripcion);
    fila('Estado', estado);
    fila('Fecha límite', _fecha(fechaLimite) ?? 'Sin fecha límite');
    fila('Preguntas', '$numPreguntas');
    fila('Respuestas recibidas', '$total');
    fila('Generado', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()));

    hoja.appendRow([TextCellValue('')]);
    hoja.appendRow([
      TextCellValue(
        'Las respuestas son anónimas: el sistema no guarda ninguna relación '
        'entre una respuesta y la persona que la envió.',
      ),
    ]);
  }

  void _hojaResultados(
    Excel excel,
    List<Map<String, dynamic>> preguntas,
    List<Map<String, dynamic>> conteos,
    int total,
  ) {
    final hoja = excel['Resultados'];
    hoja.setColumnWidth(0, 6);
    hoja.setColumnWidth(1, 50);
    hoja.setColumnWidth(2, 14);
    hoja.setColumnWidth(3, 40);
    hoja.setColumnWidth(4, 10);
    hoja.setColumnWidth(5, 12);

    _encabezado(hoja, [
      '#',
      'Pregunta',
      'Tipo',
      'Opción',
      'Votos',
      'Porcentaje',
    ]);

    var numero = 0;
    for (final p in preguntas) {
      numero++;
      final idPregunta = p['id_pregunta'];
      final tipo = (p['tipo'] ?? '').toString();

      if (tipo == 'LIBRE') {
        hoja.appendRow([
          IntCellValue(numero),
          TextCellValue((p['texto'] ?? '').toString()),
          TextCellValue('Texto libre'),
          TextCellValue('(ver hoja "Respuestas abiertas")'),
          TextCellValue(''),
          TextCellValue(''),
        ]);
        continue;
      }

      for (final o in _mapList(p['opciones'])) {
        final votos = conteos
            .where((c) =>
                c['id_pregunta'] == idPregunta &&
                c['id_opcion'] == o['id_opcion'])
            .fold<int>(0, (suma, c) => suma + ((c['total'] as num?)?.toInt() ?? 0));

        hoja.appendRow([
          IntCellValue(numero),
          TextCellValue((p['texto'] ?? '').toString()),
          TextCellValue(_tipoLegible(tipo)),
          TextCellValue((o['texto'] ?? '').toString()),
          IntCellValue(votos),
          // Se guarda como número, no como texto, para poder graficarlo.
          DoubleCellValue(total == 0 ? 0 : (votos * 100 / total)),
        ]);
      }
    }

    if (preguntas.isEmpty) {
      hoja.appendRow([TextCellValue('La encuesta no tiene preguntas.')]);
    }
  }

  void _hojaAbiertas(
    Excel excel,
    List<Map<String, dynamic>> preguntas,
    List<Map<String, dynamic>> libres,
  ) {
    final hoja = excel['Respuestas abiertas'];
    hoja.setColumnWidth(0, 50);
    hoja.setColumnWidth(1, 80);

    _encabezado(hoja, ['Pregunta', 'Respuesta']);

    var hubo = false;
    for (final p in preguntas.where((p) => p['tipo'] == 'LIBRE')) {
      final textos = libres
          .where((l) => l['id_pregunta'] == p['id_pregunta'])
          .map((l) => (l['texto_libre'] ?? '').toString())
          .where((t) => t.trim().isNotEmpty);

      for (final t in textos) {
        hubo = true;
        hoja.appendRow([
          TextCellValue((p['texto'] ?? '').toString()),
          TextCellValue(t),
        ]);
      }
    }

    if (!hubo) {
      hoja.appendRow([
        TextCellValue('No hay respuestas de texto libre.'),
      ]);
    }
  }

  /// Una fila por respuesta anónima, una columna por pregunta. Es lo que
  /// permite cruzar preguntas entre sí con una tabla dinámica.
  void _hojaDetalle(
    Excel excel,
    List<Map<String, dynamic>> preguntas,
    List<Map<String, dynamic>> detalle,
  ) {
    final hoja = excel['Detalle'];
    hoja.setColumnWidth(0, 14);
    for (var i = 0; i < preguntas.length; i++) {
      hoja.setColumnWidth(i + 1, 36);
    }

    _encabezado(hoja, [
      'Respuesta',
      ...preguntas.map((p) => (p['texto'] ?? '').toString()),
    ]);

    // Texto de cada opción, para traducir id_opcion sin volver a buscar.
    final textoOpcion = <int, String>{};
    for (final p in preguntas) {
      for (final o in _mapList(p['opciones'])) {
        final id = (o['id_opcion'] as num?)?.toInt();
        if (id != null) textoOpcion[id] = (o['texto'] ?? '').toString();
      }
    }

    // n_respuesta -> id_pregunta -> valores elegidos.
    final porRespuesta = <int, Map<int, List<String>>>{};
    for (final d in detalle) {
      final n = (d['n_respuesta'] as num?)?.toInt();
      final idPregunta = (d['id_pregunta'] as num?)?.toInt();
      if (n == null || idPregunta == null) continue;

      final idOpcion = (d['id_opcion'] as num?)?.toInt();
      final valor = idOpcion != null
          ? (textoOpcion[idOpcion] ?? 'Opción $idOpcion')
          : (d['texto_libre'] ?? '').toString();
      if (valor.trim().isEmpty) continue;

      porRespuesta.putIfAbsent(n, () => {}).putIfAbsent(idPregunta, () => []).add(valor);
    }

    if (porRespuesta.isEmpty) {
      hoja.appendRow([TextCellValue('Aún no hay respuestas.')]);
      return;
    }

    final numeros = porRespuesta.keys.toList()..sort();
    for (final n in numeros) {
      final fila = porRespuesta[n]!;
      hoja.appendRow([
        TextCellValue('Respuesta $n'),
        ...preguntas.map((p) {
          final id = (p['id_pregunta'] as num?)?.toInt();
          final valores = id == null ? null : fila[id];
          if (valores == null || valores.isEmpty) {
            return TextCellValue(_sinResponder);
          }
          // Las preguntas de opción múltiple traen varias filas.
          return TextCellValue(valores.join('; '));
        }),
      ]);
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

  List<Map<String, dynamic>> _mapList(dynamic valor) {
    if (valor is! List) return const [];
    return valor
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  String _tipoLegible(String tipo) {
    switch (tipo) {
      case 'UNICA':
        return 'Opción única';
      case 'MULTIPLE':
        return 'Opción múltiple';
      case 'LIBRE':
        return 'Texto libre';
      default:
        return tipo;
    }
  }

  String? _fecha(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  String _nombreArchivo(String titulo) {
    final limpio = titulo
        .replaceAll(RegExp(r'[^\w\sáéíóúÁÉÍÓÚñÑ-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final base = limpio.isEmpty ? 'encuesta' : limpio;
    final sello = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'encuesta_${base}_$sello.xlsx';
  }
}
