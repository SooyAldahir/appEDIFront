import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/search_api.dart';
import 'add_family_controller.dart';
import 'package:flutter/foundation.dart';

class AddFamilyPage extends StatefulWidget {
  const AddFamilyPage({super.key});
  @override
  State<AddFamilyPage> createState() => _AddFamilyPageState();
}

class _AddFamilyPageState extends State<AddFamilyPage> {
  final AddFamilyController c = AddFamilyController();
  final childSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    childSearchCtrl.dispose();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear familia'),
        backgroundColor: primary,
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ValueListenableBuilder<String>(
              valueListenable: c.familyNameListenable,
              builder: (_, name, __) => ListTile(
                leading: const Icon(Icons.family_restroom),
                title: const Text('Nombre de la familia'),
                subtitle: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 8),
            _employeeSearch(
              label: 'Papá (empleado)',
              ctrl: c.fatherCtrl,
              onChanged: (v) => c.searchEmployee(v, isFather: true),
              resultsListenable: c.fatherResults,
              onPick: c.pickFather,
            ),
            const SizedBox(height: 8),
            _employeeSearch(
              label: 'Mamá (empleado)',
              ctrl: c.motherCtrl,
              onChanged: (v) => c.searchEmployee(v, isFather: false),
              resultsListenable: c.motherResults,
              onPick: c.pickMother,
            ),

            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: c.internalResidenceListenable,
              builder: (_, internal, __) => Column(
                children: [
                  SwitchListTile.adaptive(
                    value: internal,
                    onChanged: (v) => c.internalResidence = v,
                    title: const Text('Residencia interna'),
                  ),
                  if (!internal)
                    TextField(
                      controller: c.addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dirección (requerida si es Externa)',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 32),
            const Text(
              'Hijos sanguíneos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: childSearchCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar alumno por nombre o matrícula',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: c.searchChildByText,
            ),
            ValueListenableBuilder<List<UserMini>>(
              valueListenable: c.childResults,
              builder: (_, list, __) => Column(
                children: list
                    .take(5)
                    .map(
                      (u) => ListTile(
                        dense: true,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text('${u.nombre} ${u.apellido}'.trim()),
                        subtitle: Text(
                          u.matricula != null
                              ? 'Matrícula: ${u.matricula}'
                              : '',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => c.addChild(u)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            ValueListenableBuilder<List<UserMini>>(
              valueListenable: c.children,
              builder: (_, kids, __) => Wrap(
                spacing: 6,
                runSpacing: -8,
                children: kids
                    .asMap()
                    .entries
                    .map(
                      (e) => Chip(
                        label: Text(
                          '${e.value.nombre} ${e.value.apellido}'.trim(),
                        ),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () => setState(() => c.removeChild(e.key)),
                      ),
                    )
                    .toList(),
              ),
            ),

            const SizedBox(height: 24),
            ValueListenableBuilder<bool>(
              valueListenable: c.loading,
              builder: (_, loading, __) => ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(loading ? 'Guardando...' : 'Guardar'),
                onPressed: loading ? null : () => c.save(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _employeeSearch({
    required String label,
    required TextEditingController ctrl,
    required void Function(String) onChanged,
    required ValueListenable<List<UserMini>> resultsListenable,
    required void Function(UserMini) onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: '$label (por nombre o No. empleado)',
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: onChanged,
        ),
        ValueListenableBuilder<List<UserMini>>(
          valueListenable: resultsListenable,
          builder: (_, list, __) => Column(
            children: list
                .take(5)
                .map(
                  (u) => ListTile(
                    dense: true,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text('${u.nombre} ${u.apellido}'.trim()),
                    subtitle: Text(
                      u.numEmpleado != null
                          ? 'Empleado: ${u.numEmpleado}'
                          : (u.email ?? ''),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => onPick(u),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
