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

      // Definimos si es "Juez" (Padre/Admin) o "Autor" (Hijo)
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
        // Si es Padre: Carga pendientes de la familia
        final idFamilia = user['id_familia'] ?? user['FamiliaID'];
        if (idFamilia != null) {
          datos = await _api.getPendientes(int.parse(idFamilia.toString()));
        }
      } else {
        // Si es Hijo: Carga SU historial
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
    if (!_esPadre) return; // Seguridad extra

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
                    ? _buildApproverCard(
                        item,
                      ) // Tarjeta para Padre (con botones)
                    : _buildStatusCard(
                        item,
                      ); // Tarjeta para Hijo (solo ver estado)
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

  // --- TARJETA PARA EL PADRE (Aprobar/Rechazar) ---
  Widget _buildApproverCard(Map<String, dynamic> item) {
    // ... (Copia aquí el diseño de tarjeta que te pasé en la respuesta anterior) ...
    // ... Usa _procesar para los botones ...
    // Para simplificar, aquí pongo una versión resumida:
    final baseUrl = ApiHttp.baseUrl;
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text("${item['nombre']} ${item['apellido']}"),
            subtitle: Text(item['mensaje'] ?? 'Sin texto'),
            leading: CircleAvatar(child: Text(item['nombre'][0])),
          ),
          if (item['url_imagen'] != null)
            Image.network(
              '$baseUrl${item['url_imagen']}',
              height: 200,
              fit: BoxFit.cover,
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => _procesar(item['id_post'], false),
                child: const Text(
                  "Rechazar",
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => _procesar(item['id_post'], true),
                child: const Text(
                  "Aprobar",
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TARJETA PARA EL HIJO (Ver Estado) ---
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(iconEstado, color: colorEstado, size: 30),
        title: Text(
          "Estado: $estado",
          style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(item['mensaje'] ?? 'Imagen sin texto'),
        trailing: Text(
          item['created_at'] != null
              ? item['created_at'].toString().substring(0, 10)
              : '',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
