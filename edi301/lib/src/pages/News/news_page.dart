import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/services/publicaciones_api.dart';
import 'package:edi301/src/pages/Admin/agenda/crear_evento_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/src/pages/News/news_controller.dart';
import 'package:edi301/src/pages/News/create_postpage.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final HomeController _controller = HomeController();
  final PublicacionesApi _api = PublicacionesApi();
  final ApiHttp _http = ApiHttp();

  String _userRole = '';
  int _userId = 0;
  int? _familiaId;

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
    await _loadUserData();
    _loadFeed();
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
    try {
      final lista = await _api.getGlobalFeed();
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

  // 🔥 ESTA ES LA FUNCIÓN QUE FALTABA
  String _fixUrl(String? url) {
    if (url == null || url.isEmpty || url == 'null') return '';

    // 1. Si ya es una URL completa (http...)
    if (url.startsWith('http')) {
      // Si apunta a localhost, intentamos arreglarla con la BaseUrl actual (10.0.2.2 para Android)
      if (url.contains('localhost')) {
        // Reemplazamos localhost:3000 por la base configurada en ApiHttp
        return url.replaceFirst('http://localhost:3000', ApiHttp.baseUrl);
      }
      return url;
    }

    // 2. Si es una ruta relativa (/uploads/...), le pegamos la base correcta
    final path = url.startsWith('/') ? url : '/$url';
    return '${ApiHttp.baseUrl}$path';
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';

    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) {
      return "${date.day}/${date.month}/${date.year}";
    } else if (diff.inDays >= 1) {
      return "Hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}";
    } else if (diff.inHours >= 1) {
      return "Hace ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}";
    } else if (diff.inMinutes >= 1) {
      return "Hace ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minuto' : 'minutos'}";
    } else {
      return "Hace un momento";
    }
  }

  void _toggleLike(int index) async {
    final post = _posts[index];
    final isLiked = post['is_liked'] == 1;
    final postId = post['id_post'];

    setState(() {
      _posts[index]['is_liked'] = isLiked ? 0 : 1;
      _posts[index]['likes_count'] += isLiked ? -1 : 1;
    });

    try {
      await _http.postJson('/api/publicaciones/$postId/like');
    } catch (e) {
      setState(() {
        _posts[index]['is_liked'] = isLiked ? 1 : 0;
        _posts[index]['likes_count'] += isLiked ? 1 : -1;
      });
    }
  }

  void _deletePost(int postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar publicación"),
        content: const Text("¿Estás seguro? No podrás recuperarla."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _http.deleteJson('/api/publicaciones/$postId');
      _loadFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
            'ALUMNO',
            'HijoEDI',
          ].contains(_userRole))
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.pushNamed(context, 'notifications').then((_) {
                  _loadFeed();
                });
              },
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFeed,
              child: _posts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        final item = _posts[index];
                        if (item['tipo'] == 'EVENTO') {
                          return _buildEventCard(item);
                        }
                        return _buildPostCard(item, index);
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
                ).then((_) => _loadFeed());
              },
            )
          : null,
    );
  }

  void _deleteEvent(int idEvento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Evento"),
        content: const Text(
          "¿Estás seguro de eliminar este evento de la agenda?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _http.deleteJson('/api/agenda/$idEvento');
        _loadFeed();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  Widget _buildEventCard(Map<String, dynamic> evento) {
    final fecha = DateTime.tryParse(evento['fecha_evento'].toString());
    final fechaStr = fecha != null ? "${fecha.day}/${fecha.month}" : "";
    final esAdmin = ['Admin'].contains(_userRole);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color.fromRGBO(245, 188, 6, 1), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(245, 188, 6, 1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: Colors.black),
                const SizedBox(width: 10),
                const Text(
                  "EVENTO PRÓXIMO",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  fechaStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (esAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        _deleteEvent(evento['id_evento']);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          "Eliminar",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evento['titulo'] ?? 'Evento Escolar',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(19, 67, 107, 1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  evento['mensaje'] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    // 🔥 ELIMINADA la variable 'baseUrl' local. Usamos _fixUrl.

    final nombreUsuario = "${post['nombre']} ${post['apellido'] ?? ''}";
    final nombreFamilia = post['nombre_familia'];
    final mensaje = post['mensaje'] ?? '';
    final urlImagen = post['url_imagen'];
    final tiempo = _timeAgo(post['created_at']);
    // final esHistoria = post['tipo'] == 'STORY'; // Ya no usamos historias
    final esMiPost = post['id_usuario'] == _userId;

    final likesCount = post['likes_count'] ?? 0;
    final isLiked = post['is_liked'] == 1;
    final comentariosCount = post['comentarios_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              // 🔥 Usamos _fixUrl para la foto de perfil
              backgroundImage: post['foto_perfil'] != null
                  ? NetworkImage(_fixUrl(post['foto_perfil']))
                  : null,
              child: post['foto_perfil'] == null
                  ? Text(
                      nombreUsuario[0],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            title: Text(
              nombreUsuario,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle:
                (nombreFamilia != null && nombreFamilia.toString().isNotEmpty)
                ? Text(
                    "Con la $nombreFamilia",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                : null,
            trailing: esMiPost
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deletePost(post['id_post']);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                  )
                : null,
          ),

          // 2. IMAGEN (Doble Tap para Like)
          // 🔥 Usamos _fixUrl aquí para arreglar la imagen
          if (urlImagen != null &&
              urlImagen.toString().isNotEmpty &&
              urlImagen != 'null')
            GestureDetector(
              onDoubleTap: () => _toggleLike(index),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    width: double.infinity,
                    color: Colors.black12,
                    child: Image.network(
                      _fixUrl(urlImagen), // <--- USO DE LA FUNCIÓN
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const SizedBox(
                        height: 200,
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _toggleLike(index),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$likesCount",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                InkWell(
                  onTap: () => _showCommentsModal(context, post['id_post']),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.grey,
                        size: 26,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$comentariosCount",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          if (mensaje.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "$nombreUsuario ",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: mensaje),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tiempo,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showCommentsModal(BuildContext context, int postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsSheet(
        postId: postId,
        http: _http,
        currentUserId: _userId,
        currentUserRole: _userRole,
        fixUrl: _fixUrl, // 🔥 Pasamos la función al modal
      ),
    );
  }

  bool _shouldShowFab() {
    return true;
  }
}

// -----------------------------------------------------------------------------
// WIDGET EXTRA: HOJA DE COMENTARIOS
// -----------------------------------------------------------------------------
class CommentsSheet extends StatefulWidget {
  final int postId;
  final ApiHttp http;
  final int currentUserId;
  final String currentUserRole;
  final Function(String?) fixUrl; // 🔥 Recibimos la función

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.http,
    required this.currentUserId,
    required this.currentUserRole,
    required this.fixUrl,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  List<dynamic> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final res = await widget.http.getJson(
        '/api/publicaciones/${widget.postId}/comentarios',
      );
      if (mounted) {
        setState(() {
          _comments = jsonDecode(res.body);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    try {
      await widget.http.postJson(
        '/api/publicaciones/${widget.postId}/comentarios',
        data: {'contenido': text},
      );
      _loadComments();
    } catch (e) {
      print("Error enviando comentario: $e");
    }
  }

  void _deleteComment(int commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar comentario"),
        content: const Text("¿Deseas borrar este comentario?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.http.deleteJson(
          '/api/publicaciones/comentarios/$commentId',
        );
        _loadComments();
      } catch (e) {
        print("Error al borrar: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const Text(
            "Comentarios",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                ? const Center(child: Text("Sé el primero en comentar 👇"))
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (ctx, i) {
                      final c = _comments[i];
                      final nombre = "${c['nombre']} ${c['apellido'] ?? ''}";
                      final soyDueno = c['id_usuario'] == widget.currentUserId;
                      final soyAdmin = [
                        'Admin',
                        'PapaEDI',
                        'MamaEDI',
                      ].contains(widget.currentUserRole);
                      final puedoBorrar = soyDueno || soyAdmin;

                      // 🔥 Usamos fixUrl aquí
                      final fotoUrl = widget.fixUrl(c['foto_perfil']);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage: c['foto_perfil'] != null
                              ? NetworkImage(fotoUrl)
                              : null,
                          child: c['foto_perfil'] == null
                              ? Text(nombre[0])
                              : null,
                        ),
                        title: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c['contenido'],
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        trailing: puedoBorrar
                            ? IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    _deleteComment(c['id_comentario']),
                              )
                            : null,
                        onLongPress: puedoBorrar
                            ? () => _deleteComment(c['id_comentario'])
                            : null,
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
              left: 10,
              right: 10,
              top: 5,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: "Escribe un comentario...",
                      fillColor: Colors.grey[200],
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
