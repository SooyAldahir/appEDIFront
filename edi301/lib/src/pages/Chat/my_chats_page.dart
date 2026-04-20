import 'dart:async';
import 'package:flutter/material.dart';
import 'package:edi301/services/chat_api.dart';
import 'package:edi301/src/pages/Chat/chat_page.dart';
import 'package:edi301/core/api_client_http.dart';

class MyChatsPage extends StatefulWidget {
  const MyChatsPage({super.key});

  /// ValueNotifier global que home_page escucha para mostrar el badge del menú.
  static final ValueNotifier<int> totalUnread = ValueNotifier<int>(0);

  @override
  State<MyChatsPage> createState() => _MyChatsPageState();
}

class _MyChatsPageState extends State<MyChatsPage> {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final ChatApi _api = ChatApi();
  List<dynamic> _chats = [];
  bool _loading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _refreshSilently();
    });
  }

  Future<void> _refreshSilently() async {
    try {
      final chats = await _api.getMyChats();
      if (mounted) {
        setState(() => _chats = chats);
        _updateTotalUnread(chats);
      }
    } catch (_) {}
  }

  Future<void> _loadChats() async {
    setState(() => _loading = true);
    try {
      final chats = await _api.getMyChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _loading = false;
        });
        _updateTotalUnread(chats);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Suma los unread de todos los chats y actualiza el ValueNotifier global.
  void _updateTotalUnread(List<dynamic> chats) {
    int total = 0;
    for (final c in chats) {
      if (c is Map) {
        total += (c['unread_count'] ?? 0) as int;
      }
    }
    MyChatsPage.totalUnread.value = total;
  }

  String _absUrl(String raw) {
    if (raw.isEmpty || raw == 'null') return '';
    var s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    s = s.replaceAll('\\', '/');
    final idxPublic = s.indexOf('public/uploads/');
    if (idxPublic != -1) s = s.substring(idxPublic + 'public'.length);
    final idxUploads = s.indexOf('/uploads/');
    if (idxUploads != -1) {
      s = s.substring(idxUploads);
    } else if (s.startsWith('uploads/')) {
      s = '/$s';
    } else if (!s.startsWith('/')) {
      s = '/$s';
    }
    return '${ApiHttp.baseUrl}$s';
  }

  String _formatDate(String? fechaIso) {
    if (fechaIso == null) return '';
    final date = DateTime.parse(fechaIso).toLocal();
    final now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }

  void _goToChat(Map<String, dynamic> chat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          idSala: chat['id_sala'],
          nombreChat: chat['titulo_chat'] ?? 'Chat',
        ),
      ),
    );
    // Al volver del chat: recargar para actualizar badges
    _loadChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Conversaciones',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _loading
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
                          'No tienes chats activos',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadChats,
                    color: _primary,
                    child: ListView.builder(
                      itemCount: _chats.length,
                      itemBuilder: (ctx, i) {
                        final chat = _chats[i] as Map<String, dynamic>;
                        final tipo = chat['tipo'] as String? ?? '';
                        final fotoRaw =
                            (chat['foto_perfil_chat'] ?? '').toString();
                        final fotoAbs = _absUrl(fotoRaw);
                        final unread = (chat['unread_count'] ?? 0) as int;
                        final hasUnread = unread > 0;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasUnread ? Colors.white : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: hasUnread
                                ? Border.all(
                                    color: _primary.withOpacity(0.25),
                                    width: 1.5,
                                  )
                                : Border.all(color: Colors.grey.shade200),
                            boxShadow: hasUnread
                                ? [
                                    BoxShadow(
                                      color: _primary.withOpacity(0.07),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  tipo == 'GRUPAL' ? Colors.orange : _primary,
                              backgroundImage:
                                  (tipo != 'GRUPAL' && fotoAbs.isNotEmpty)
                                      ? NetworkImage(fotoAbs)
                                      : null,
                              child: (tipo != 'GRUPAL' && fotoAbs.isNotEmpty)
                                  ? null
                                  : Icon(
                                      tipo == 'GRUPAL'
                                          ? Icons.groups
                                          : Icons.person,
                                      color: Colors.white,
                                    ),
                            ),
                            title: Text(
                              chat['titulo_chat'] ?? 'Desconocido',
                              style: TextStyle(
                                fontWeight: hasUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: hasUnread
                                    ? Colors.black87
                                    : Colors.black54,
                              ),
                            ),
                            subtitle: Text(
                              chat['ultimo_mensaje'] ??
                                  'Inicia la conversación...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hasUnread
                                    ? Colors.black87
                                    : Colors.grey[600],
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                fontStyle: chat['ultimo_mensaje'] == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatDate(chat['fecha_ultimo'] as String?),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        hasUnread ? _primary : Colors.grey,
                                    fontWeight: hasUnread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (hasUnread) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => _goToChat(chat),
                          ),
                        );
                      },
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _gold,
        child: const Icon(Icons.info, color: Colors.black),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ve a la sección de Familias o Alumnos para iniciar un chat.',
              ),
            ),
          );
        },
      ),
    );
  }
}
