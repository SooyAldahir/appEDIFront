import 'package:flutter/material.dart';
import 'package:edi301/services/users_api.dart';
import 'package:edi301/models/user.dart';
import 'package:edi301/core/api_client_http.dart';

class BirthdaysPage extends StatefulWidget {
  const BirthdaysPage({super.key});

  @override
  State<BirthdaysPage> createState() => _BirthdaysPageState();
}

class _BirthdaysPageState extends State<BirthdaysPage> {
  final UsersApi _api = UsersApi();
  List<User> _cumpleaneros = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarCumpleaneros();
  }

  void _cargarCumpleaneros() async {
    final lista = await _api.getCumpleanerosHoy();
    if (mounted) {
      setState(() {
        _cumpleaneros = lista;
        _loading = false;
      });
    }
  }

  void _irAlChat(User usuario) {
    Navigator.pushNamed(
      context,
      'chat',
      arguments: {
        'id_usuario': usuario.idUsuario,
        'nombre': "${usuario.name} ${usuario.lastName ?? ''}",
        'foto_perfil': usuario.urlFotoPerfil,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cumpleaños de Hoy 🎂"),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cumpleaneros.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cumpleaneros.length,
              itemBuilder: (context, index) {
                final user = _cumpleaneros[index];
                return _buildBirthdayCard(user);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cake_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            "Hoy no hay cumpleaños registrados.",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayCard(User user) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.pinkAccent, width: 2),
      ),
      color: Colors.pink[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "🎉 ¡ES SU CUMPLEAÑOS! 🎉",
              style: TextStyle(
                color: Colors.pink,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 15),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              backgroundImage: user.urlFotoPerfil != null
                  ? NetworkImage("${ApiHttp.baseUrl}${user.urlFotoPerfil}")
                  : null,
              child: user.urlFotoPerfil == null
                  ? Text(user.name[0], style: const TextStyle(fontSize: 30))
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              "${user.name} ${user.lastName ?? ''}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _irAlChat(user),
              icon: const Icon(Icons.chat_bubble),
              label: const Text("Enviar Felicitación"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
