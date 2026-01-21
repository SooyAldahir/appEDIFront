import 'dart:async';
import 'package:flutter/material.dart';
import 'package:edi301/services/chat_api.dart';

class ChatPage extends StatefulWidget {
  final int idSala;
  final String nombreChat;

  const ChatPage({super.key, required this.idSala, required this.nombreChat});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatApi _api = ChatApi();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<dynamic> _mensajes = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final msgs = await _api.getMessages(widget.idSala);
    if (mounted) {
      setState(() {
        _mensajes = msgs;
        _loading = false;
      });
      if (!silent) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    final success = await _api.sendMessage(widget.idSala, text);

    if (success) {
      _loadMessages(silent: true);
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error al enviar mensaje")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreChat),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _mensajes.isEmpty
                ? const Center(child: Text("Inicia la conversación..."))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(10),
                    itemCount: _mensajes.length,
                    itemBuilder: (ctx, i) {
                      final msg = _mensajes[i];
                      final esMio = msg['es_mio'] == 1 || msg['es_mio'] == true;

                      return Align(
                        alignment: esMio
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: esMio
                                ? const Color.fromRGBO(245, 188, 6, 1)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: esMio
                                  ? const Radius.circular(15)
                                  : Radius.zero,
                              bottomRight: esMio
                                  ? Radius.zero
                                  : const Radius.circular(15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!esMio)
                                Text(
                                  msg['nombre_remitente'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              Text(
                                msg['mensaje'],
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
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
