import 'package:flutter/material.dart';
import 'package:edi301/services/familia_api.dart';
import 'dart:async';

class GetFamilyController {
  late BuildContext context;
  final FamiliaApi _familiaApi = FamiliaApi();

  // Lista completa de familias (la fuente de la verdad)
  List<dynamic> _allFamilies = [];

  // Lista filtrada que se muestra en pantalla
  ValueNotifier<List<dynamic>> families = ValueNotifier([]);
  ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> init(BuildContext context) async {
    this.context = context;
    await loadFamilies();
  }

  Future<void> loadFamilies() async {
    isLoading.value = true;
    try {
      // Usamos el endpoint que ya ordena por num_alumnos
      final data = await _familiaApi.getAvailable();
      if (data != null) {
        _allFamilies = List<dynamic>.from(data);
        // Inicialmente mostramos todas
        families.value = _allFamilies;
      }
    } catch (e) {
      print('Error cargando familias: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchChanged(String query) {
    if (query.isEmpty) {
      families.value = _allFamilies;
      return;
    }

    final lowerQuery = query.toLowerCase();

    families.value = _allFamilies.where((f) {
      final nombre = (f['nombre_familia'] ?? '').toString().toLowerCase();
      final padres = (f['padres'] ?? '').toString().toLowerCase();

      return nombre.contains(lowerQuery) || padres.contains(lowerQuery);
    }).toList();
  }

  void goToDetail(dynamic familia) {
    // Asumiendo que 'family_detail' es la ruta de admin para ver detalles
    Navigator.pushNamed(
      context,
      'family_detail',
      arguments: familia['id_familia'],
    );
  }
}
