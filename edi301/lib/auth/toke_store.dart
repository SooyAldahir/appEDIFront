import 'package:flutter/foundation.dart';
import 'token_storage.dart';

class AuthStore extends ChangeNotifier {
  final TokenStorage _storage;
  String? _token;

  AuthStore(this._storage);

  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    _token = await _storage.read();
    notifyListeners();
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _storage.save(token);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    await _storage.clear();
    notifyListeners();
  }
}
