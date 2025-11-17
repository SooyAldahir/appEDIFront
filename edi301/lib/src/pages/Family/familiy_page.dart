import 'dart:convert';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: FamilyWidget(
                backgroundImage:
                    'assets/img/familia-extensa-e1591818033557.jpg',
                circleImage:
                    'assets/img/los-24-mandamientos-de-la-familia-feliz-lg.jpg',
                onTap: () {},
              ),
            ),
            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: FamilyData(
                familyName: 'Familia Ballina Nuñez',
                numChildres: '6',
                text: 'Hijos EDI',
                description: 'Tu descripcion aqui',
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
                    child: _buildHijosList(),
                  )
                : _buildFotosGrid(),
          ],
        ),
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
                _controller.goToEditPage(context, familyId: id);
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

  Widget _buildHijosList() {
    return const Column(
      children: [
        ProfileCard(
          imageUrl: 'https://cdn-icons-png.flaticon.com/512/7141/7141724.png',
          name: 'Aldahir Ballina',
          school: 'Ingenieria',
          age: 21,
          phoneNumber: '961 900 1640',
        ),
        SizedBox(height: 10),
        ProfileCard(
          imageUrl: 'https://cdn-icons-png.flaticon.com/512/7141/7141724.png',
          name: 'Karen Ballina',
          school: 'CIED - QUIBI',
          age: 19,
          phoneNumber: '123 456 7890',
        ),
        SizedBox(height: 10),
        ProfileCard(
          imageUrl: 'https://cdn-icons-png.flaticon.com/512/7141/7141724.png',
          name: 'Emmanuel Chavez',
          school: 'Ingenieria',
          age: 21,
          phoneNumber: '111 222 3333',
        ),
      ],
    );
  }

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
  final String backgroundImage;
  final String circleImage;
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
          child: Image.asset(
            backgroundImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
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
                backgroundImage: AssetImage(circleImage),
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

class ProfileCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String school;
  final int age;
  final String phoneNumber;

  const ProfileCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.school,
    required this.age,
    required this.phoneNumber,
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
                Text('Escuela: $school'),
                Text('Edad: $age'),
                Text('Teléfono: $phoneNumber'),
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
                  school,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                Text(
                  'Edad: $age',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                Text(
                  'Tel: $phoneNumber',
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
