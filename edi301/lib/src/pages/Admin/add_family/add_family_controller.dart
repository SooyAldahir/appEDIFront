// lib/src/pages/Admin/add_family/add_family_controller.dart
import 'package:edi301/constants/member_types.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/search_api.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/services/members_api.dart';
import 'package:flutter/foundation.dart';

class AddFamilyController {
  static final ValueNotifier<List<Family>> familyList =
      ValueNotifier<List<Family>>([]);

  final ValueNotifier<String> _familyName = ValueNotifier<String>('');
  String get familyName => _familyName.value;
  set familyName(String v) => _familyName.value = v;
  ValueListenable<String> get familyNameListenable => _familyName;

  final ValueNotifier<bool> _internalResidence = ValueNotifier<bool>(true);
  bool get internalResidence => _internalResidence.value;
  set internalResidence(bool v) => _internalResidence.value = v;
  ValueListenable<bool> get internalResidenceListenable => _internalResidence;

  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController fatherCtrl = TextEditingController();
  final TextEditingController motherCtrl = TextEditingController();
  final ValueNotifier<List<UserMini>> fatherResults =
      ValueNotifier<List<UserMini>>([]);
  final ValueNotifier<List<UserMini>> motherResults =
      ValueNotifier<List<UserMini>>([]);
  UserMini? _pickedFather;
  UserMini? _pickedMother;
  final TextEditingController searchChildCtrl = TextEditingController();
  final ValueNotifier<List<UserMini>> childResults =
      ValueNotifier<List<UserMini>>([]);
  final ValueNotifier<List<UserMini>> children = ValueNotifier<List<UserMini>>(
    [],
  );

  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);
  ValueListenable<bool> get loading => _loading;

  final _searchApi = SearchApi();
  final _familiaApi = FamiliaApi();
  final _membersApi = MembersApi();

  void dispose() {
    addressCtrl.dispose();
    fatherCtrl.dispose();
    motherCtrl.dispose();
    searchChildCtrl.dispose();
    fatherResults.dispose();
    motherResults.dispose();
    childResults.dispose();
    children.dispose();
    _familyName.dispose();
    _internalResidence.dispose();
    _loading.dispose();
  }

  void recomputeFamilyName() {
    final f = _pickedFather?.apellido.trim().split(' ').first ?? '';
    final m = _pickedMother?.apellido.trim().split(' ').first ?? '';
    final base = [f, m].where((e) => e.isNotEmpty).join(' ');
    _familyName.value = base.isEmpty ? '' : 'Familia $base';
  }

  Future<void> searchEmployee(String q, {required bool isFather}) async {
    q = q.trim();
    final target = isFather ? fatherResults : motherResults;

    if (q.isEmpty) {
      target.value = [];
      return;
    }

    final res = await _searchApi.searchAll(q);
    final merged = <int, UserMini>{};
    for (final u in res.empleados) merged[u.id] = u;
    for (final u in res.externos) merged[u.id] = u;
    target.value = merged.values.toList();
  }

  void pickFather(UserMini u) => _pickParent(u, true);
  void pickMother(UserMini u) => _pickParent(u, false);

  void _pickParent(UserMini u, bool isFather) {
    if (isFather) {
      _pickedFather = u;
      fatherCtrl.text = '${u.nombre} ${u.apellido}'.trim();
      fatherResults.value = [];
    } else {
      _pickedMother = u;
      motherCtrl.text = '${u.nombre} ${u.apellido}'.trim();
      motherResults.value = [];
    }
    recomputeFamilyName();
  }

  Future<void> searchChildByText(String q) async {
    q = q.trim();
    if (q.isEmpty) {
      childResults.value = [];
      return;
    }
    final res = await _searchApi.searchAll(q);
    childResults.value = res.alumnos;
  }

  void addChild(UserMini u) {
    final list = [...children.value];
    if (!list.any((x) => x.id == u.id)) {
      list.add(u);
      children.value = list;
    }
  }

  void removeChild(int index) {
    final list = [...children.value];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      children.value = list;
    }
  }

  Future<void> save(BuildContext context) async {
    _loading.value = true;
    try {
      final isInternal = _internalResidence.value;
      final direccion = isInternal ? null : addressCtrl.text.trim();

      if (!isInternal && (direccion == null || direccion.isEmpty)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La dirección es requerida para residencia EXTERNA',
              ),
            ),
          );
        }
        return;
      }
      if (_pickedFather == null && _pickedMother == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona al menos Papá o Mamá')),
          );
        }
        return;
      }
      final hijosIds = children.value.map((kid) => kid.id).toList();
      final created = await _familiaApi.createFamily(
        nombreFamilia: _familyName.value.trim().isEmpty
            ? 'Familia'
            : _familyName.value.trim(),
        residencia: isInternal ? 'INTERNA' : 'EXTERNA',
        direccion: direccion,
        papaId: _pickedFather?.id,
        mamaId: _pickedMother?.id,
        hijos: hijosIds,
      );

      final withNames = created.copyWith(
        fatherName: _pickedFather == null
            ? null
            : '${_pickedFather!.nombre} ${_pickedFather!.apellido}'.trim(),
        motherName: _pickedMother == null
            ? null
            : '${_pickedMother!.nombre} ${_pickedMother!.apellido}'.trim(),
      );

      final list = [...AddFamilyController.familyList.value]..add(withNames);
      AddFamilyController.familyList.value = list;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Familia y miembros creados con éxito')),
        );
        Navigator.of(context).pop(true);
      }

      _pickedFather = null;
      _pickedMother = null;
      fatherCtrl.clear();
      motherCtrl.clear();
      addressCtrl.clear();
      children.value = [];
      _familyName.value = '';
      _internalResidence.value = true;
      fatherResults.value = [];
      motherResults.value = [];
      childResults.value = [];
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      _loading.value = false;
    }
  }
}
