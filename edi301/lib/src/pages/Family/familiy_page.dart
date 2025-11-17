import 'dart:convert';

import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/models/family_model.dart'; // --- CAMBIO: Necesario para List<FamilyMember> ---
import 'package:edi301/services/familia_api.dart';
import 'package:flutter/material.dart';
import 'package:edi301/src/pages/Family/family_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FamiliyPage extends StatefulWidget {
  const FamiliyPage({super.key});

  @override
  State<FamiliyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamiliyPage> {
  bool mostrarHijos = true;
  final FamilyController _controller = FamilyController();
  final FamiliaApi _familiaApi = FamiliaApi();
  late Future<Family?> _familyFuture;
  @override
  void initState() {
    super.initState();
    // Inicia la carga de datos de la familia
    _familyFuture = _fetchFamilyData();
  }

  Future<Family?> _fetchFamilyData() async {
    try {
      // 1. Resolver el ID de la familia
      final int? familyId = await _controller.resolveFamilyId();
      if (familyId == null) {
        throw Exception('No se pudo encontrar el ID de la familia.');
      }

      // 2. Obtener el token de autenticación
      final prefs = await SharedPreferences.getInstance();
      // Asumimos que el token se guarda con la lave 'token'
      final String? authToken = prefs.getString('token');

      // 3. Llamar a la API para obtener los datos de la familia
      final data = await _familiaApi.getById(familyId, authToken: authToken);
      if (data != null) {
        // 4. Convertir el JSON a un objeto Family
        return Family.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error al cargar datos de la familia: $e');
      // Opcional: mostrar un SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Family?>(
        future: _familyFuture,
        builder: (context, snapshot) {
          // --- ESTADO DE CARGA ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- ESTADO DE ERROR ---
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No se pudieron cargar los datos de la familia.\n${snapshot.error ?? ''}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // --- ESTADO DE ÉXITO ---
          final family = snapshot.data!;
          final String baseUrl = ApiHttp.baseUrl;

          // Lógica para determinar la imagen de portada
          final ImageProvider coverImage;
          final String? coverUrl = family.fotoPortadaUrl;
          if (coverUrl != null && coverUrl.isNotEmpty) {
            coverImage = NetworkImage('$baseUrl$coverUrl');
          } else {
            coverImage = const AssetImage(
              'assets/img/familia-extensa-e1591818033557.jpg',
            );
          }

          // Lógica para determinar la imagen de perfil
          final ImageProvider profileImage;
          final String? profileUrl = family.fotoPerfilUrl;
          if (profileUrl != null && profileUrl.isNotEmpty) {
            profileImage = NetworkImage('$baseUrl$profileUrl');
          } else {
            profileImage = const AssetImage(
              'assets/img/los-24-mandamientos-de-la-familia-feliz-lg.jpg',
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 200,
                  // --- MODIFICADO ---
                  child: FamilyWidget(
                    backgroundImage: coverImage, // Usar imagen dinámica
                    circleImage: profileImage, // Usar imagen dinámica
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  // --- MODIFICADO ---
                  child: FamilyData(
                    familyName: family.familyName,
                    numChildres:
                        (family.householdChildren.length +
                                family.assignedStudents.length)
                            .toString(),
                    text: 'Hijos EDI',
                    description:
                        family.descripcion ??
                        'Añade una descripción en "Editar Perfil".', // Descripción dinámica
                  ),
                ),
                const SizedBox(height: 5),
                _bottomEditProfile(),
                const SizedBox(height: 10),
                _buildToggleButtons(),
                const SizedBox(height: 10),
                mostrarHijos
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        // --- CAMBIO: Combina ambas listas antes de pasarlas ---
                        child: () {
                          // 1. Crea una lista combinada
                          final List<FamilyMember> todosLosHijos = [
                            ...family.householdChildren,
                            ...family.assignedStudents,
                          ];
                          // 2. Pasa la lista combinada al widget
                          return _buildHijosList(todosLosHijos);
                        }(),
                      )
                    : _buildFotosGrid(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bottomEditProfile() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ElevatedButton(
        onPressed: () async {
          print('🔘 Botón "Editar Perfil" presionado');

          // Intenta obtener el ID de la familia
          final prefs = await SharedPreferences.getInstance();
          final rawUser = prefs.getString('user');

          if (rawUser != null) {
            final user = jsonDecode(rawUser);
            print('👤 Usuario actual: ${user['nombre']} ${user['apellido']}');
            print('🔑 Claves disponibles: ${user.keys.toList()}');

            // Busca el id_familia en diferentes formatos
            final idFamilia =
                user['id_familia'] ??
                user['FamiliaID'] ??
                user['familia_id'] ??
                user['idFamilia'];

            print('🆔 ID Familia encontrado: $idFamilia');

            if (idFamilia != null) {
              final id = int.tryParse(idFamilia.toString());
              print('🔢 ID parseado: $id');

              if (id != null && id > 0) {
                // --- CAMBIO: Navega a 'edit' y espera un resultado ---
                // Si la página 'edit' devuelve 'true', recarga los datos.
                final result = await Navigator.pushNamed(
                  context,
                  'edit',
                  arguments: id,
                );
                if (result == true) {
                  setState(() {
                    _familyFuture = _fetchFamilyData();
                  });
                }
                // --- FIN CAMBIO ---
                return;
              }
            }
          }

          // Fallback
          print(
            '⚠️ No se encontró ID en SharedPreferences, usando método de resolución',
          );
          _controller.goToEditPage(context);
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'Editar Perfil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildToggleButton('Mis hijos EDI', mostrarHijos, () {
          setState(() {
            mostrarHijos = true;
          });
        }),
        const SizedBox(width: 10),
        _buildToggleButton('Fotos', !mostrarHijos, () {
          setState(() {
            mostrarHijos = false;
          });
        }),
      ],
    );
  }

  Widget _buildToggleButton(
    String text,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color.fromARGB(190, 245, 189, 6)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(
        text,
        style: TextStyle(color: isSelected ? Colors.black : Colors.black),
      ),
    );
  }

  // --- CAMBIO: La función ahora acepta la lista de hijos ---
  Widget _buildHijosList(List<FamilyMember> hijos) {
    // Si no hay hijos, muestra un mensaje
    if (hijos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('No hay hijos EDI registrados en esta familia.'),
        ),
      );
    }

    // Si hay hijos, crea la lista dinámicamente
    return ListView.separated(
      physics:
          const NeverScrollableScrollPhysics(), // No hacer scroll dentro del SingleChildScrollView
      shrinkWrap: true, // Ajustar altura al contenido
      itemCount: hijos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final hijo = hijos[index];
        return ProfileCard(
          // El modelo FamilyMember no tiene URL de imagen, usamos un placeholder.
          imageUrl: 'https://cdn-icons-png.flaticon.com/512/7141/7141724.png',
          name: hijo.fullName,
          school: hijo.carrera, // Usa el campo 'carrera'
          fechaNacimiento:
              hijo.fechaNacimiento, // Usa el campo 'fechaNacimiento'
          phoneNumber: hijo.telefono, // Usa el campo 'telefono'
        );
      },
    );
  }
  // --- FIN CAMBIO ---

  Widget _buildFotosGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Container(color: Colors.amber);
      },
    );
  }
}

class FamilyWidget extends StatelessWidget {
  final ImageProvider backgroundImage;
  final ImageProvider circleImage;
  final VoidCallback onTap;

  const FamilyWidget({
    super.key,
    required this.backgroundImage,
    required this.circleImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          child: Image(
            image: backgroundImage, // Usar ImageProvider
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
            // Opcional: Manejo de errores de carga de imagen
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          child: GestureDetector(
            onTap: onTap,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 46,
                backgroundImage: circleImage, // Usar ImageProvider
                // Opcional: Manejo de errores de carga de imagen
                onBackgroundImageError: (exception, stackTrace) {
                  // No hace nada, pero evita un crash si la imagen de perfil falla
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FamilyData extends StatelessWidget {
  final String familyName;
  final String numChildres;
  final String text;
  final String description;

  const FamilyData({
    super.key,
    required this.familyName,
    required this.numChildres,
    required this.text,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          familyName,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            const SizedBox(height: 10),
            Text(
              numChildres,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 16)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          description,
          textAlign: TextAlign.justify,
          style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
        ),
      ],
    );
  }
}

// --- CAMBIO: Modificada la 'ProfileCard' para aceptar los datos del modelo ---
class ProfileCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String? school;
  final String? fechaNacimiento;
  final String? phoneNumber;

  const ProfileCard({
    super.key,
    required this.imageUrl,
    required this.name,
    this.school,
    this.fechaNacimiento,
    this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Mostrar un diálogo con la información del hijo
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(imageUrl),
                  radius: 50,
                ),
                const SizedBox(height: 10),
                Text('Escuela: ${school ?? 'No registrada'}'),
                Text('Nacimiento: ${fechaNacimiento ?? 'No registrada'}'),
                Text('Teléfono: ${phoneNumber ?? 'No registrado'}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(245, 189, 6, 0.452),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(imageUrl), radius: 30),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  school ?? 'Escuela no registrada',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                Text(
                  'Nacimiento: ${fechaNacimiento ?? 'No registrada'}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                Text(
                  'Tel: ${phoneNumber ?? 'No registrado'}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// --- FIN CAMBIO ---