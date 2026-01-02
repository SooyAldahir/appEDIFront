import 'dart:convert';
import 'package:edi301/services/publicaciones_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/src/pages/News/news_controller.dart';
import 'package:edi301/src/pages/News/create_postpage.dart';
// Asegúrate de importar tu página de Notificaciones si tiene otro nombre
// import 'package:edi301/src/pages/Notifications/notifications_page.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final HomeController _controller = HomeController();
  final PublicacionesApi _api = PublicacionesApi(); // <--- Instancia API

  String _userRole = '';
  int _userId = 0;
  int? _familiaId;

  // Variables para el feed
  bool _loading = true;
  List<dynamic> _posts = [];

  @override
  void initState() {
    super.initState();
    _initData();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context);
    });
  }

  Future<void> _initData() async {
    await _loadUserData(); // Carga usuario y ID familia
    if (_familiaId != null) {
      _loadFeed(); // Si tenemos familia, cargamos noticias
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final user = jsonDecode(userStr);
      if (mounted) {
        setState(() {
          _userRole = user['nombre_rol'] ?? user['rol'] ?? '';
          _userId = user['id_usuario'] ?? 0;
          final fId = user['id_familia'] ?? user['FamiliaID'];
          if (fId != null) _familiaId = int.tryParse(fId.toString());
        });
      }
    }
  }

  Future<void> _loadFeed() async {
    if (_familiaId == null) return;
    try {
      final lista = await _api.getPostsFamilia(_familiaId!);
      if (mounted) {
        setState(() {
          _posts = lista;
          _loading = false;
        });
      }
    } catch (e) {
      print("Error cargando feed: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Fondo gris suave
      appBar: AppBar(
        title: const Text('Noticias', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if ([
            'Admin',
            'Padre',
            'Madre',
            'Tutor',
            'PapaEDI',
            'MamaEDI',
            'Hijo',
            'HijoEDI',
            'ALUMNO',
            'Estudiante',
          ].contains(_userRole))
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.pushNamed(context, 'notifications').then((_) {
                  // Al volver de aprobar, recargamos el feed
                  _loadFeed();
                });
              },
            ),
          const SizedBox(width: 10),
        ],
      ),

      // --- BODY DEL FEED ---
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFeed,
              child: _posts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        bottom: 80,
                      ), // Espacio para el FAB
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        return _buildPostCard(_posts[index]);
                      },
                    ),
            ),

      floatingActionButton: _shouldShowFab()
          ? FloatingActionButton(
              backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
              child: const Icon(Icons.add, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreatePostPage(
                      idUsuario: _userId,
                      idFamilia: _familiaId,
                    ),
                  ),
                ).then((_) => _loadFeed()); // Recargar al volver
              },
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      // ListView para que funcione el RefreshIndicator
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.newspaper, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                "Aún no hay noticias.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              Text(
                "¡Sé el primero en publicar algo!",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    // URL Base para imágenes
    const baseUrl =
        'http://192.168.100.41:3000'; // O usa ApiHttp.baseUrl si es pública
    // Ajusta la URL según tu ApiHttp.baseUrl

    final nombre = "${post['nombre']} ${post['apellido'] ?? ''}";
    final mensaje = post['mensaje'] ?? '';
    final urlImagen = post['url_imagen'];
    final fecha = post['created_at'] != null
        ? post['created_at'].toString().substring(0, 10)
        : '';
    final esHistoria = post['tipo'] == 'STORY';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera (Usuario y Fecha)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: esHistoria
                  ? Colors.purple[100]
                  : Colors.blue[100],
              child: Text(
                nombre[0],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(fecha),
            trailing: esHistoria
                ? const Chip(
                    label: Text("Historia", style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                  )
                : null,
          ),

          // 2. Imagen (Si tiene)
          if (urlImagen != null && urlImagen.toString().isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              width: double.infinity,
              color: Colors.black12,
              child: Image.network(
                '$baseUrl$urlImagen', // Asegúrate de que baseUrl esté bien
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Icon(
                      Icons.broken_image,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

          // 3. Texto del Post
          if (mensaje.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(mensaje, style: const TextStyle(fontSize: 15)),
            ),

          // 4. Botones de interacción (Like/Comentar - Visuales por ahora)
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.favorite_border, color: Colors.grey),
                label: const Text(
                  "Me gusta",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                label: const Text(
                  "Comentar",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _shouldShowFab() {
    // ... tu lógica de roles ...
    const rolesPermitidos = [
      'Admin',
      'Padre',
      'Madre',
      'Tutor',
      'PapaEDI',
      'MamaEDI',
      'Hijo',
      'HijoEDI',
      'ALUMNO',
      'Estudiante',
    ];
    return rolesPermitidos.contains(_userRole);
  }
}
