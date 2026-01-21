import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/publicaciones_api.dart';
import 'package:edi301/core/api_client_http.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final PublicacionesApi _api = PublicacionesApi();
  List<dynamic> _items = [];
  bool _loading = true;
  String _userRole = '';
  bool _esPadre = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');

    if (userStr != null) {
      final user = jsonDecode(userStr);
      final rol = user['nombre_rol'] ?? user['rol'] ?? '';
      final esJuez = [
        'Admin',
        'Padre',
        'Madre',
        'Tutor',
        'PapaEDI',
        'MamaEDI',
      ].contains(rol);

      List<dynamic> datos = [];

      if (esJuez) {
        final idFamilia = user['id_familia'] ?? user['FamiliaID'];
        if (idFamilia != null) {
          datos = await _api.getPendientes(int.parse(idFamilia.toString()));
        }
      } else {
        datos = await _api.getMisPosts();
      }

      if (mounted) {
        setState(() {
          _userRole = rol;
          _esPadre = esJuez;
          _items = datos;
          _loading = false;
        });
      }
    }
  }

  Future<void> _procesar(int idPost, bool aprobar) async {
    if (!_esPadre) return;

    final index = _items.indexWhere((p) => p['id_post'] == idPost);
    final itemBackup = index != -1 ? _items[index] : null;

    setState(() {
      _items.removeWhere((p) => p['id_post'] == idPost);
    });

    final estado = aprobar ? 'Publicado' : 'Rechazada';
    final exito = await _api.responderSolicitud(idPost, estado);

    if (!exito && itemBackup != null && mounted) {
      setState(() => _items.insert(index, itemBackup));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error al procesar")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esPadre ? "Solicitudes Pendientes" : "Mis Publicaciones"),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return _esPadre
                    ? _buildApproverCard(item)
                    : _buildStatusCard(item);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _esPadre ? Icons.check_circle_outline : Icons.history,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _esPadre ? "¡Todo al día!" : "Sin actividad reciente",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApproverCard(Map<String, dynamic> item) {
    String? rawUrl = item['url_imagen'];
    String urlFinal = "";

    if (rawUrl != null && rawUrl.isNotEmpty) {
      if (rawUrl.startsWith('http')) {
        urlFinal = rawUrl;
      } else {
        urlFinal = '${ApiHttp.baseUrl}$rawUrl';
      }
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
              child: Text(
                (item['nombre'] != null && item['nombre'].isNotEmpty)
                    ? item['nombre'][0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              "${item['nombre']} ${item['apellido']}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(item['mensaje'] ?? 'Solicita publicar esto...'),
            trailing: Text(
              item['created_at'] != null
                  ? item['created_at'].toString().substring(0, 10)
                  : '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          if (urlFinal.isNotEmpty)
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.black12,
              child: Image.network(
                urlFinal,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Error url: $urlFinal",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _procesar(item['id_post'], false),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text("Rechazar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[400],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _procesar(item['id_post'], true),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text("Aprobar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> item) {
    final estado = item['estado'];
    Color colorEstado = Colors.grey;
    IconData iconEstado = Icons.watch_later_outlined;

    if (estado == 'Publicado' || estado == 'Aprobada') {
      colorEstado = Colors.green;
      iconEstado = Icons.check_circle;
    } else if (estado == 'Rechazada') {
      colorEstado = Colors.red;
      iconEstado = Icons.cancel;
    } else if (estado == 'Pendiente') {
      colorEstado = Colors.orange;
      iconEstado = Icons.hourglass_top;
    }

    String? rawUrl = item['url_imagen'];
    String urlFinal = "";

    if (rawUrl != null && rawUrl.isNotEmpty) {
      if (rawUrl.startsWith('http')) {
        urlFinal = rawUrl;
      } else {
        urlFinal = '${ApiHttp.baseUrl}$rawUrl';
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(iconEstado, color: colorEstado, size: 30),
            title: Text(
              "Estado: $estado",
              style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(item['mensaje'] ?? 'Sin descripción'),
            trailing: Text(
              item['created_at'] != null
                  ? item['created_at'].toString().substring(0, 10)
                  : '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (urlFinal.isNotEmpty)
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[200],
              child: Image.network(
                urlFinal,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
