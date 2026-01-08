import 'package:flutter/material.dart';
import 'package:edi301/services/chat_api.dart';
import 'package:edi301/src/pages/Chat/chat_page.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener intl en pubspec.yaml para fechas, si no, usa un string simple

class MyChatsPage extends StatefulWidget {
  const MyChatsPage({super.key});

  @override
  State<MyChatsPage> createState() => _MyChatsPageState();
}

class _MyChatsPageState extends State<MyChatsPage> {
  final ChatApi _api = ChatApi();
  List<dynamic> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  // Volvemos a cargar cada vez que entramos a la pantalla por si hubo mensajes nuevos
  Future<void> _loadChats() async {
    setState(() => _loading = true);
    try {
      final chats = await _api.getMyChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Función para formatear fecha (Ej: 14:30 o Ayer)
  String _formatDate(String? fechaIso) {
    if (fechaIso == null) return "";
    final date = DateTime.parse(fechaIso).toLocal();
    final now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      // Es hoy, mostramos hora
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else {
      // Es otro día, mostramos fecha
      return "${date.day}/${date.month}";
    }
  }

  void _goToChat(Map<String, dynamic> chat) async {
    // Navegamos y esperamos. Al volver, recargamos la lista.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          idSala: chat['id_sala'],
          nombreChat: chat['titulo_chat'] ?? 'Chat',
        ),
      ),
    );
    _loadChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Conversaciones"),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "No tienes chats activos",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (ctx, i) {
                final chat = _chats[i];
                final tipo = chat['tipo']; // 'PRIVADO' o 'GRUPAL'

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tipo == 'GRUPAL'
                        ? Colors.orange
                        : const Color.fromRGBO(19, 67, 107, 1),
                    child: Icon(
                      tipo == 'GRUPAL' ? Icons.groups : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    chat['titulo_chat'] ?? 'Desconocido',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    chat['ultimo_mensaje'] ?? 'Imagen o Archivo...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: chat['ultimo_mensaje'] == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  trailing: Text(
                    _formatDate(chat['fecha_ultimo']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () => _goToChat(chat),
                );
              },
            ),
      // Botón flotante para iniciar nuevo chat (opcional, lleva a lista de usuarios)
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
        child: const Icon(Icons.info, color: Colors.black),
        onPressed: () {
          // Aquí podrías abrir un modal o navegar a tu lista de contactos/usuarios
          // para seleccionar a alguien y llamar a initPrivateChat
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Ve a la sección de Familias o Alumnos para iniciar un chat.",
              ),
            ),
          );
        },
      ),
    );
  }
}
