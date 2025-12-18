// lib/src/pages/Admin/add_alumns/add_alumns_page.dart
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/search_api.dart';
import 'add_alumns_controller.dart';

class AddAlumnsPage extends StatefulWidget {
  const AddAlumnsPage({super.key});

  @override
  State<AddAlumnsPage> createState() => _AddAlumnsPageState();
}

class _AddAlumnsPageState extends State<AddAlumnsPage> {
  final _controller = AddAlumnsController();
  // Key para forzar la reconstrucción del Autocomplete de alumnos
  Key _alumnAutocompleteKey = UniqueKey();
  final _alumnSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.init(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar Alumnos a Familia'),
        backgroundColor: primary,
      ),
      body: ResponsiveContent(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFamilySelector(),
                const SizedBox(height: 30),
                const Text(
                  'Buscar y Añadir Alumnos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                _buildAlumnSelector(),
                const SizedBox(height: 20),
                _buildSelectedAlumnsList(),
                const SizedBox(height: 40),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Este widget ya está funcionando bien, no requiere cambios.
  Widget _buildFamilySelector() {
    return ValueListenableBuilder<Family?>(
      valueListenable: _controller.selectedFamily,
      builder: (context, selectedFamily, child) {
        return Autocomplete<Family>(
          displayStringForOption: (family) => family.familyName,
          optionsBuilder: (textEditingValue) {
            if (selectedFamily != null) {
              return const Iterable<Family>.empty();
            }
            return _controller.searchFamilies(textEditingValue.text);
          },
          onSelected: (family) {
            _controller.selectFamily(family);
            FocusScope.of(context).unfocus();
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                if (selectedFamily != null) {
                  textEditingController.text = selectedFamily.familyName;
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Familia Seleccionada',
                      filled: true,
                      fillColor: Colors.grey[200],
                      prefixIcon: const Icon(Icons.family_restroom),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Cambiar familia',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clearFamily();
                          textEditingController.clear();
                        },
                      ),
                    ),
                  );
                } else {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: '1. Buscar familia por nombre',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
        );
      },
    );
  }

  /// Widget con la lógica corregida para evitar el crash.
  Widget _buildAlumnSelector() {
    return Column(
      children: [
        // 1. El campo de texto para buscar
        TextField(
          controller: _alumnSearchCtrl,
          decoration: InputDecoration(
            labelText: '2. Buscar alumno por matrícula o nombre',
            prefixIcon: const Icon(Icons.person_search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) {
            // Llama al controlador para que busque
            _controller.searchAlumns(value);
          },
        ),
        const SizedBox(height: 8),

        // 2. La lista de resultados que aparece debajo
        ValueListenableBuilder<List<UserMini>>(
          valueListenable: _controller.alumnSearchResults,
          builder: (context, results, child) {
            if (results.isEmpty) {
              return const SizedBox.shrink(); // No mostrar nada si no hay resultados
            }
            // Limita la altura de la lista de resultados
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Card(
                elevation: 2,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final alumn = results[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.school)),
                      title: Text('${alumn.nombre} ${alumn.apellido}'),
                      subtitle: Text('Matrícula: ${alumn.matricula ?? 'N/A'}'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.green,
                        ),
                        tooltip: 'Añadir alumno',
                        onPressed: () {
                          // Al hacer clic aquí...
                          _controller.addAlumn(
                            alumn,
                          ); // ...se añade a los Chips...
                          _alumnSearchCtrl
                              .clear(); // ...se limpia el campo de texto...
                          FocusScope.of(
                            context,
                          ).unfocus(); // ...y se oculta el teclado.
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // El resto de los widgets no necesitan cambios
  Widget _buildSelectedAlumnsList() {
    return ValueListenableBuilder<List<UserMini>>(
      valueListenable: _controller.selectedAlumns,
      builder: (context, alumns, child) {
        if (alumns.isEmpty) {
          return const Center(
            child: Text(
              'Ningún alumno añadido todavía.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: alumns
              .map(
                (alumn) => Chip(
                  label: Text('${alumn.nombre} ${alumn.apellido}'),
                  avatar: const Icon(Icons.school),
                  onDeleted: () => _controller.removeAlumn(alumn),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (context, isLoading, child) {
          return ElevatedButton.icon(
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(isLoading ? 'GUARDANDO...' : 'GUARDAR ASIGNACIONES'),
            onPressed: isLoading ? null : _controller.saveAssignments,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}
