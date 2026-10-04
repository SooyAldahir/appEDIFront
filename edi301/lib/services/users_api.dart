import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/token_storage.dart';
import '../core/api_client_http.dart';
import '../core/api_error.dart';
import '../models/user.dart';
import 'package:edi301/models/family_model.dart' as fm;

class UsersApi {
  final ApiHttp _http = ApiHttp();

  Future<List<User>> getCumpleanerosHoy() async {
    try {
      final res = await _http.getJson('/api/usuarios/cumpleanos');

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);

        return data.map((x) => User.fromJson(x)).toList();
      }
    } catch (e) {
      print('Error obteniendo cumpleaños: $e');
    }
    return [];
  }

  Future<bool> updateFcmToken(int idUsuario, String fcmToken) async {
    try {
      final response = await _http.putJson(
        '/api/usuarios/update-token',
        data: {'id_usuario': idUsuario, 'fcm_token': fcmToken},
      );

      if (response.statusCode != 200) {
        print(
          "❌ Error del servidor: ${response.statusCode} - ${response.body}",
        );
      }
      return response.statusCode == 200;
    } catch (e) {
      print("Error actualizando FCM Token: $e");
      return false;
    }
  }

  Future<void> deleteSoft(int id) async {
    final res = await _http.deleteJson('/api/usuarios/$id');
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
  }

  /// Elimina (desactiva) la cuenta del usuario autenticado.
  ///
  /// El backend conserva las relaciones (familia, mensajes, publicaciones)
  /// y libera el correo, matrícula y núm. empleado para permitir que la
  /// persona se registre nuevamente con los mismos datos si así lo desea.
  ///
  /// El código viaja en la misma petición: el servidor lo verifica y da de
  /// baja en una sola operación, o no hace ninguna de las dos. Antes la app
  /// comprobaba el código por su cuenta y luego pedía la baja, así que
  /// llamando directo a la ruta se saltaba la comprobación entera.
  Future<void> deleteMyAccount(String codigo) async {
    final res = await _http.deleteJson(
      '/api/usuarios/me',
      data: {'codigo': codigo},
    );
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
  }

  // ── Multi-dispositivo: gestión de sesiones ─────────────────────────────

  /// Lista las sesiones activas del usuario autenticado.
  Future<List<Map<String, dynamic>>> listMySessions() async {
    final res = await _http.getJson('/api/usuarios/me/sesiones');
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// Cierra una sesión específica del usuario autenticado.
  Future<void> revokeSession(int idSesion) async {
    final res = await _http.deleteJson('/api/usuarios/me/sesiones/$idSesion');
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
  }

  /// Cierra todas las sesiones del usuario excepto la actual.
  Future<int> revokeAllOtherSessions() async {
    final res = await _http.deleteJson('/api/usuarios/me/sesiones');
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['cerradas'] is int) return body['cerradas'] as int;
    } catch (_) {}
    return 0;
  }

  Future<List<fm.Family>> familiasByDocumento({
    int? matricula,
    int? numEmpleado,
  }) async {
    final res = await _http.getJson(
      '/api/usuarios/familias/by-doc/search',
      query: {
        if (matricula != null) 'matricula': matricula,
        if (numEmpleado != null) 'numEmpleado': numEmpleado,
      },
    );

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => fm.Family.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is Map && data.values.length == 1 && data.values.first is List) {
      return (data.values.first as List)
          .map((e) => fm.Family.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <fm.Family>[];
  }

  Future<User> registerAlumno({
    required int matricula,
    required String nombre,
    required String apellido,
    required String email,
    required String contrasena,
    String? estado,
  }) async {
    final payload = {
      "TipoUsuario": "ALUMNO",
      "Matricula": matricula,
      "Nombre": nombre,
      "Apellido": apellido,
      "E_mail": email,
      "Contrasena": contrasena,
      "Estado": estado,
    };
    final res = await _http.postJson('/api/usuarios/register', data: payload);
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    final id = (jsonDecode(res.body) as Map)['IdUsuario'] as int;
    return getById(id);
  }

  Future<User> registerEmpleado({
    required int numEmpleado,
    required String nombre,
    required String apellido,
    required String email,
    required String contrasena,
    String? estado,
  }) async {
    final payload = {
      "TipoUsuario": "EMPLEADO",
      "NumEmpleado": numEmpleado,
      "Nombre": nombre,
      "Apellido": apellido,
      "E_mail": email,
      "Contrasena": contrasena,
      "Estado": estado,
    };
    final r = await _http.postJson('/api/usuarios/register', data: payload);
    if (r.statusCode >= 400) {
      throw Exception(parseHttpError(r));
    }
    final id = (jsonDecode(r.body) as Map)['IdUsuario'] as int;
    return getById(id);
  }

  Future<User> registerExterno({
    required String nombre,
    required String apellido,
    required String email,
    required String contrasena,
    required int idRol,
    String? telefono,
    String? direccion,
    String? fechaNacimiento,
  }) async {
    final payload = {
      "nombre": nombre,
      "apellido": apellido,
      "correo": email,
      "contrasena": contrasena,
      "tipo_usuario": "EXTERNO",
      "id_rol": idRol,
      "matricula": null,
      "num_empleado": null,
      if (telefono != null && telefono.isNotEmpty) "telefono": telefono,
      if (direccion != null && direccion.isNotEmpty) "direccion": direccion,
      if (fechaNacimiento != null) "fecha_nacimiento": fechaNacimiento,
    };

    final res = await _http.postJson('/api/usuarios', data: payload);

    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final id = data['id_usuario'] ?? data['IdUsuario'] as int;

    return getById(id);
  }

  Future<User> login(String email, String password) async {
    final r = await _http.postJson(
      '/api/usuarios/login',
      data: {"E_mail": email, "Contrasena": password},
    );
    if (r.statusCode >= 400) {
      throw Exception(parseHttpError(r));
    }
    final Map<String, dynamic> data =
        jsonDecode(r.body) as Map<String, dynamic>;

    final user = User.fromJson(data);

    final token = (data['session_token'] ?? data['token'] ?? '').toString();
    if (token.isNotEmpty) {
      // El token va SOLO al almacén seguro; en prefs queda nada más el perfil,
      // que no es un secreto. Antes también se escribía aquí en texto plano.
      await TokenStorage().save(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(data));
    }
    return user;
  }

  Future<User> getById(int id) async {
    final r = await _http.getJson('/api/usuarios/$id');
    if (r.statusCode >= 400) {
      throw Exception(parseHttpError(r));
    }

    final Map<String, dynamic> data =
        jsonDecode(r.body) as Map<String, dynamic>;

    return User.fromJson(data);
  }

  Future<List<fm.Family>> getAvailableFamilies() async {
    final res = await _http.getJson('/api/familias/available');
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((f) => fm.Family.fromJson(f)).toList();
    }
    return [];
  }

  Future<List<User>> search({String? q, String? tipo}) async {
    final r = await _http.getJson(
      '/api/usuarios',
      query: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      },
    );
    if (r.statusCode >= 400) {
      throw Exception(parseHttpError(r));
    }
    final decoded = jsonDecode(r.body);
    if (decoded is List) {
      return decoded
          .map<User>((e) => User.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (decoded is Map &&
        decoded.values.length == 1 &&
        decoded.values.first is List) {
      final list = decoded.values.first as List;
      return list
          .map<User>((e) => User.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return <User>[];
  }

  Future<User> update(
    int id, {
    String? nombre,
    String? apellido,
    String? estado,
    bool? esActivo,
    bool? esAdmin,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      if (nombre != null) "Nombre": nombre,
      if (apellido != null) "Apellido": apellido,
      if (estado != null) "Estado": estado,
      if (esActivo != null) "es_Activo": esActivo,
      if (esAdmin != null) "es_Admin": esAdmin,
    };

    final r = await _http.patchJson('/api/usuarios/$id', data: payload);
    if (r.statusCode >= 400) {
      throw Exception(parseHttpError(r));
    }

    final Map<String, dynamic> data =
        jsonDecode(r.body) as Map<String, dynamic>;
    return User.fromJson(data);
  }

  /// Verifica si el correo existe en la BD. Lanza [Exception] con mensaje amigable si no existe.
  /// Comprueba si un correo tiene cuenta.
  ///
  /// Ya NO se usa en la recuperación de contraseña. Respondía 404 cuando el
  /// correo no estaba registrado, y eso convertía la API en una forma cómoda
  /// de averiguar quién tiene cuenta en la universidad. El flujo nuevo pide
  /// el código sin preguntar antes, y el servidor contesta lo mismo exista o
  /// no la cuenta.
  Future<void> checkEmailExists(String email) async {
    final res = await _http.postJson(
      '/api/auth/verificar-correo',
      data: {'correo': email},
    );
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
  }

  /// Pide al SERVIDOR que mande un código al correo.
  ///
  /// Antes esto lo hacía la app llamando directo al servicio de OTP, con las
  /// credenciales de servicio escritas dentro del código y, por tanto, dentro
  /// del APK. Ahora la app solo dice "manda un código a este correo".
  ///
  /// `proposito`: RESET, REGISTRO, BAJA o PROMOCION.
  ///
  /// Lanza si el correo no tiene cuenta (404) o si ya la tiene cuando no
  /// debería (409). Quien llama NO debe avanzar de pantalla si esto lanza.
  ///
  /// Devuelve el mensaje del servidor para mostrarlo tal cual: así el texto
  /// vive en un solo sitio y no hay que recompilar la app para cambiarlo.
  Future<String> enviarCodigoVerificacion(
    String correo, {
    String proposito = 'RESET',
  }) async {
    final res = await _http.postJson(
      '/api/auth/enviar-codigo',
      data: {'correo': correo, 'proposito': proposito},
    );
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {}
    return 'Te enviamos un código a tu correo.';
  }

  /// Cambia la contraseña. El código se manda EN LA MISMA petición.
  ///
  /// Esto es lo importante del cambio: ya no hay un paso "verificar código"
  /// separado que la app pudiera saltarse o interpretar mal. El servidor
  /// verifica y cambia en la misma operación, o no hace nada.
  Future<ResultadoReset> resetPasswordConCodigo(
    String correo,
    String codigo,
    String nuevaContrasena,
  ) async {
    final res = await _http.postJson(
      '/api/auth/reset-password',
      data: {
        'correo': correo,
        'codigo': codigo,
        'nuevaContrasena': nuevaContrasena,
      },
    );

    if (res.statusCode == 200) return const ResultadoReset.exito();

    // `motivo` dice a qué paso volver sin tener que leer el texto del error.
    String? motivo;
    try {
      final body = jsonDecode(res.body);
      if (body is Map) motivo = body['motivo']?.toString();
    } catch (_) {}

    return ResultadoReset.error(
      mensaje: parseHttpError(res),
      codigoInvalido: motivo == 'codigo',
    );
  }
}

/// Resultado de cambiar la contraseña.
///
/// Se distingue el código inválido del resto de errores porque la pantalla
/// tiene que reaccionar distinto: con un código malo hay que volver a pedirlo,
/// con una contraseña débil la persona se queda donde está corrigiéndola.
class ResultadoReset {
  final bool ok;
  final bool codigoInvalido;
  final String mensaje;

  const ResultadoReset.exito()
      : ok = true,
        codigoInvalido = false,
        mensaje = 'Contraseña actualizada con éxito';

  const ResultadoReset.error({
    required this.mensaje,
    this.codigoInvalido = false,
  }) : ok = false;
}
