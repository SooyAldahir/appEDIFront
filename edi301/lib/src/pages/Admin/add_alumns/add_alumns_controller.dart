// lib/src/pages/Admin/add_alumns/add_alumns_controller.dart
import 'package:flutter/material.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/search_api.dart';
import 'package:edi301/services/members_api.dart';
import 'package:edi301/constants/member_types.dart';

class AddAlumnsController {
  BuildContext? context;
  final _searchApi = SearchApi();
  final _membersApi = MembersApi();

  final loading = ValueNotifier<bool>(false);

  // --- Estado que la UI observará ---
  final ValueNotifier<Family?> selectedFamily = ValueNotifier(null);
  final ValueNotifier<List<UserMini>> selectedAlumns = ValueNotifier([]);

  final ValueNotifier<List<UserMini>> alumnSearchResults = ValueNotifier([]);

  void init(BuildContext context) {
    this.context = context;
  }

  void dispose() {
    loading.dispose();
    selectedFamily.dispose();
    selectedAlumns.dispose();
    alumnSearchResults.dispose();
  }

  // --- Lógica de Búsqueda ---

  /// Busca familias por nombre para el autocompletado.
  Future<List<Family>> searchFamilies(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final result = await _searchApi.searchAll(query);
      // Convertimos FamilyMini a Family para mantener consistencia
      return result.familias
          .map((f) => Family(id: f.id, familyName: f.nombre))
          .toList();
    } catch (e) {
      debugPrint('Error buscando familias: $e');
      return [];
    }
  }

  /// Busca alumnos por matrícula o nombre para el autocompletado.
  Future<void> searchAlumns(String query) async {
    if (query.trim().isEmpty) {
      alumnSearchResults.value = [];
      return;
    }
    try {
      final result = await _searchApi.searchAll(query);
      final currentIds = selectedAlumns.value.map((a) => a.id).toSet();
      alumnSearchResults.value = result.alumnos
          .where((a) => !currentIds.contains(a.id))
          .toList();
    } catch (e) {
      debugPrint('Error buscando alumnos: $e');
      alumnSearchResults.value = [];
    }
  }

  // --- Lógica de Selección ---

  void selectFamily(Family family) {
    selectedFamily.value = family;
  }

  void clearFamily() {
    selectedFamily.value = null;
  }

  void addAlumn(UserMini alumn) {
    final currentList = selectedAlumns.value;
    if (!currentList.any((a) => a.id == alumn.id)) {
      selectedAlumns.value = [...currentList, alumn];
    }
    alumnSearchResults.value = [];
  }

  void removeAlumn(UserMini alumn) {
    final currentList = selectedAlumns.value;
    currentList.removeWhere((a) => a.id == alumn.id);
    selectedAlumns.value = [...currentList];
  }

  // --- Lógica de Guardado ---

  Future<void> saveAssignments() async {
    // 1. Validaciones
    if (selectedFamily.value == null) {
      _snack('Por favor, selecciona una familia.');
      return;
    }
    if (selectedAlumns.value.isEmpty) {
      _snack('Por favor, añade al menos un alumno.');
      return;
    }

    loading.value = true;

    try {
      // 2. Preparar los datos
      final familyId = selectedFamily.value!.id!;
      final alumnIds = selectedAlumns.value.map((alumn) => alumn.id).toList();

      // 3. Llamar a la API "bulk" UNA SOLA VEZ
      await _membersApi.addMembersBulk(
        idFamilia: familyId,
        idUsuarios: alumnIds,
      );

      loading.value = false;

      // 4. Éxito
      if (context!.mounted) {
        _snack(
          '${alumnIds.length} alumno(s) asignado(s) con éxito.',
          isError: false,
        );
        Navigator.pop(context!, true);
      }
    } catch (e) {
      // 5. Manejar el error de la API
      loading.value = false;
      // Esto te mostrará el error exacto del backend (si lo hay)
      _snack(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  void _snack(String msg, {bool isError = true}) {
    if (context?.mounted ?? false) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }
}
