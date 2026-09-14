// lib/services/members_api.dart
import 'dart:convert';

import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';
import 'package:edi301/models/family_model.dart';

class MembersApi {
  final ApiHttp _http = ApiHttp();

  /// Agrega un miembro y devuelve el `id_miembro` recién creado (o `null` si
  /// el backend no lo regresó). Ese id es necesario para poder quitarlo
  /// después sin tener que recargar toda la familia.
  Future<int?> addMember({
    required int idFamilia,
    required int idUsuario,
    required String tipoMiembro,
  }) async {
    // Se normaliza contra MemberType para que el valor enviado siempre coincida
    // con lo que acepta el backend (PADRE, MADRE, HIJO, ALUMNO_ASIGNADO,
    // TIO_EDI). Antes ALUMNO_ASIGNADO se rechazaba aquí aunque el API sí lo
    // acepta.
    final type = MemberType.normalize(tipoMiembro);
    if (type == MemberType.desconocido) {
      throw Exception('Tipo de miembro inválido: "$tipoMiembro".');
    }
    final payload = {
      'id_familia': idFamilia,
      'id_usuario': idUsuario,
      'tipo_miembro': type,
    };
    final res = await _http.postJson('/api/miembros', data: payload);
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        final raw =
            decoded['id_miembro'] ??
            (decoded['data'] is Map
                ? (decoded['data'] as Map)['id_miembro']
                : null);
        if (raw is num) return raw.toInt();
        if (raw != null) return int.tryParse(raw.toString());
      }
    } catch (_) {
      // El cuerpo no era JSON: el alta sí ocurrió, solo no tenemos el id.
    }
    return null;
  }

  Future<void> addMembersBulk({
    required int idFamilia,
    required List<int> idUsuarios,
  }) async {
    final payload = {'id_familia': idFamilia, 'id_usuarios': idUsuarios};
    final res = await _http.postJson('/api/miembros/bulk', data: payload);
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
  }

  Future<void> removeMember(int idMiembro) async {
    final res = await _http.deleteJson('/api/miembros/$idMiembro');
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
  }
}
