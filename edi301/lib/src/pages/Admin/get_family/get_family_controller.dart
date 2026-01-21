import 'dart:async';
import 'package:flutter/material.dart';
import 'package:edi301/models/family_model.dart' as fm;
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/src/pages/Admin/add_family/add_family_controller.dart'
    show AddFamilyController;

class GetFamilyController {
  final searchCtrl = TextEditingController();
  final ValueNotifier<List<fm.Family>> results = ValueNotifier<List<fm.Family>>(
    [],
  );

  final _api = FamiliaApi();
  Timer? _debounce;
  late BuildContext _ctx;

  Future<void> init(BuildContext context) async {
    _ctx = context;
    searchCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    final q = searchCtrl.text.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => search(q));
  }

  Future<void> searchNow() => search(searchCtrl.text);

  Future<void> search(String raw) async {
    var q = raw.trim();
    if (q.isEmpty) {
      results.value = [];
      return;
    }

    q = q
        .replaceFirst(RegExp(r'^\s*familia\s+', caseSensitive: false), '')
        .trim();

    try {
      final data = await _api.buscarFamiliasPorNombre(q);
      results.value = data.map((m) => fm.Family.fromJson(m)).toList();
    } catch (e) {
      if (_ctx.mounted) {
        ScaffoldMessenger.of(
          _ctx,
        ).showSnackBar(SnackBar(content: Text('Error al buscar familias: $e')));
      }
      final data = await _api.buscarFamiliasPorNombre(q);
      results.value = data.map((m) => fm.Family.fromJson(m)).toList();
      AddFamilyController.familyList.value = results.value;
    }
  }

  void dispose() {
    _debounce?.cancel();
    searchCtrl.dispose();
    results.dispose();
  }
}
