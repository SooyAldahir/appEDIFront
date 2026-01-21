import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';

class EstadosApi {
  final ApiHttp _http = ApiHttp();

  Future<List<dynamic>> getCatalogo() async {
    final res = await _http.getJson('/api/estados/catalogo');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<bool> updateEstado(int idUsuario, int idCatEstado) async {
    final res = await _http.postJson(
      '/api/estados',
      data: {
        'id_usuario': idUsuario,
        'id_cat_estado': idCatEstado,
        'unico_vigente': true,
      },
    );
    return res.statusCode == 201 || res.statusCode == 200;
  }
}
