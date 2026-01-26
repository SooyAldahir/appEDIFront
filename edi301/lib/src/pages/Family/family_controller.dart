import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/users_api.dart';

class FamilyController {
  BuildContext? context;
  final UsersApi _usersApi = UsersApi();

  Future? init(BuildContext context) {
    this.context = context;
    return null;
  }

  Future<int?> resolveFamilyId() => _resolveFamilyId();

  Future<void> goToEditPage(BuildContext context, {int? familyId}) async {
    if (familyId != null && familyId > 0) {
      Navigator.pushNamed(context, 'edit', arguments: familyId);
      return;
    }

    final id = await _resolveFamilyId();

    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo identificar la familia del usuario.'),
        ),
      );
      return;
    }

    Navigator.pushNamed(context, 'edit', arguments: id);
  }

  Future<int?> _resolveFamilyId() async {
    final cachedId = await _readFamilyIdFromSession();
    if (cachedId != null) return cachedId;
    return _fetchFamilyIdByDocument();
  }

  Future<int?> _readFamilyIdFromSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString('user');
    if (rawUser == null) return null;

    try {
      final dynamic decoded = jsonDecode(rawUser);
      return _extractFamilyId(decoded);
    } catch (_) {
      return null;
    }

    return null;
  }

  int? _extractFamilyId(dynamic data) {
    if (data == null) return null;

    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key.contains('familia') && key.contains('id')) {
          final parsed = _asInt(entry.value);
          if (parsed != null) {
            return parsed;
          }
        }
      }
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is Map || value is List) {
          final nested = _extractFamilyId(value);
          if (nested != null) return nested;
        }
      }
    } else if (data is List) {
      for (final item in data) {
        final nested = _extractFamilyId(item);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Future<int?> _fetchFamilyIdByDocument() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUser = prefs.getString('user');
      if (rawUser == null) return null;
      final Map<String, dynamic> user = Map<String, dynamic>.from(
        jsonDecode(rawUser) as Map,
      );

      final matricula = _asInt(user['matricula'] ?? user['Matricula']);
      final numEmpleado = _asInt(user['numEmpleado'] ?? user['NumEmpleado']);
      if (matricula == null && numEmpleado == null) return null;

      final familias = await _usersApi.familiasByDocumento(
        matricula: matricula,
        numEmpleado: numEmpleado,
      );
      if (familias.isEmpty) return null;
      return familias.first.id;
    } catch (_) {
      return null;
    }
  }
}
