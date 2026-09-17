import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda el `session_token` en el almacén seguro del sistema: Keychain en iOS
/// y Keystore / EncryptedSharedPreferences en Android.
///
/// Antes el token vivía además en SharedPreferences (texto plano en disco), que
/// era de donde lo leían `ApiHttp` y el socket. Con el desbloqueo biométrico eso
/// no se sostiene: de nada sirve pedir huella si el token se puede leer del
/// archivo. Ahora esta clase es la ÚNICA fuente de verdad y [migrateLegacyToken]
/// se encarga de mover lo que hubiera quedado de la versión anterior.
class TokenStorage {
  static const _key = 'auth_token';

  /// Clave vieja en SharedPreferences. Solo se usa para migrar y borrar.
  static const _legacyPrefsKey = 'session_token';

  static const _storage = FlutterSecureStorage(
    // encryptedSharedPreferences evita el backend antiguo de Android, que en
    // algunos equipos corrompía las claves tras restaurar un respaldo.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Caché en memoria: el token se pide en CADA petición HTTP y llegar al
  /// Keychain/Keystore es bastante más lento que a SharedPreferences.
  static String? _cached;
  static bool _loaded = false;

  Future<void> save(String token) async {
    _cached = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  Future<String?> read() async {
    if (_loaded) return _cached;
    try {
      _cached = await _storage.read(key: _key);
    } catch (_) {
      // El almacén seguro puede fallar (keystore corrupto tras un restore,
      // por ejemplo). Se trata como "sin sesión" en vez de reventar.
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
    // Por si quedó algo de la versión anterior.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyPrefsKey);
    } catch (_) {}
  }

  /// Vacía la caché para que la próxima lectura vuelva al almacén seguro.
  void invalidateCache() {
    _cached = null;
    _loaded = false;
  }

  /// Mueve el token de SharedPreferences al almacén seguro, si hiciera falta.
  ///
  /// Se llama una vez al arrancar la app. Sin esto, al actualizar, todos los
  /// usuarios con sesión abierta quedarían deslogueados de golpe.
  Future<void> migrateLegacyToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_legacyPrefsKey);
      if (legacy == null || legacy.isEmpty) return;

      final current = await read();
      if (current == null || current.isEmpty) {
        await save(legacy);
      }
      // En cualquier caso se borra la copia insegura.
      await prefs.remove(_legacyPrefsKey);
    } catch (_) {
      // Si la migración falla el usuario solo tendrá que iniciar sesión otra
      // vez; no vale la pena impedir el arranque por esto.
    }
  }
}
