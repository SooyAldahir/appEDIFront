import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/core/api_client_http.dart';

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  // ── Colores ────────────────────────────────────────────────────────────────
  static const _red    = Color(0xFFB71C1C);
  static const _redL   = Color(0xFFC62828);
  static const _bg     = Color(0xFFF0F4F8);

  // ── Tipos de alerta ────────────────────────────────────────────────────────
  static const _tipos = [
    _TipoAlerta(
      key:   'ANUNCIO',
      label: 'Anuncio',
      emoji: '📢',
      color: Color(0xFF1565C0),
      icon:  Icons.campaign_rounded,
      hint:  'Comunicado general para toda la comunidad',
    ),
    _TipoAlerta(
      key:   'EMERGENCIA',
      label: 'Emergencia',
      emoji: '🚨',
      color: Color(0xFFB71C1C),
      icon:  Icons.warning_amber_rounded,
      hint:  'Aviso urgente — suspensión, accidente, etc.',
    ),
    _TipoAlerta(
      key:   'EVENTO',
      label: 'Evento',
      emoji: '📅',
      color: Color(0xFF00695C),
      icon:  Icons.event_rounded,
      hint:  'Actividad o evento próximo para todos',
    ),
    _TipoAlerta(
      key:   'INFORMATIVO',
      label: 'Informativo',
      emoji: 'ℹ️',
      color: Color(0xFF4527A0),
      icon:  Icons.info_outline_rounded,
      hint:  'Información general o recordatorio',
    ),
  ];

  // ── Estado ─────────────────────────────────────────────────────────────────
  int    _tipoIdx  = 0;
  bool   _loading  = false;
  String? _error;

  final _formKey    = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  _TipoAlerta get _tipoActual => _tipos[_tipoIdx];

  // ── Envío ──────────────────────────────────────────────────────────────────
  Future<void> _confirmarYEnviar() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        tipo:    _tipoActual,
        titulo:  _tituloCtrl.text.trim(),
        mensaje: _mensajeCtrl.text.trim(),
      ),
    );
    if (confirmed != true) return;

    setState(() { _loading = true; _error = null; });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        final uStr = prefs.getString('user');
        if (uStr != null) {
          final u = jsonDecode(uStr);
          token = u['token'] ?? u['session_token'] ?? u['access_token'];
        }
      }

      final url = Uri.parse('${ApiHttp.baseUrl}/api/alertas/broadcast');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'titulo':  _tituloCtrl.text.trim(),
          'mensaje': _mensajeCtrl.text.trim(),
          'tipo':    _tipoActual.key,
          'emoji':   _tipoActual.emoji,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final enviados = data['enviados'] ?? data['data']?['enviados'] ?? '?';
        _showSuccess(enviados.toString());
        _tituloCtrl.clear();
        _mensajeCtrl.clear();
      } else {
        setState(() {
          _error = 'Error ${res.statusCode}: ${res.body}';
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _showSuccess(String enviados) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade600, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Alerta enviada!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Notificación enviada a $enviados usuarios.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Listo',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader()),

            // Tipo selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildTipoSelector(),
              ),
            ),

            // Formulario
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildForm(),
              ),
            ),

            // Advertencia
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildWarningBanner(),
              ),
            ),

            // Botón enviar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: _buildSendButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_red, _redL],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3)),
                ),
                child: const Text(
                  'SOLO ADMINISTRADORES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alerta Instantánea',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Envía una notificación a todos los usuarios',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Tipo de alerta',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2B45)),
          ),
        ),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tipos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final t = _tipos[i];
              final selected = i == _tipoIdx;
              return GestureDetector(
                onTap: () => setState(() => _tipoIdx = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 96,
                  decoration: BoxDecoration(
                    color: selected ? t.color : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? t.color
                          : Colors.grey.shade200,
                      width: selected ? 0 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: t.color.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 6),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Hint del tipo seleccionado
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Padding(
            key: ValueKey(_tipoIdx),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(_tipoActual.icon,
                    color: _tipoActual.color, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _tipoActual.hint,
                    style: TextStyle(
                        color: _tipoActual.color,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            const Text('Título',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2B45))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tituloCtrl,
              maxLength: 80,
              decoration: _inputDecoration(
                hint: 'Ej: Suspensión de clases hoy',
                icon: Icons.title_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El título es requerido' : null,
            ),
            const SizedBox(height: 16),

            // Mensaje
            const Text('Mensaje',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2B45))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _mensajeCtrl,
              maxLines: 5,
              maxLength: 500,
              decoration: _inputDecoration(
                hint: 'Escribe el mensaje completo aquí...',
                icon: Icons.message_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El mensaje es requerido' : null,
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _tipoActual.color, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Colors.red, width: 1.5),
      ),
      counterStyle:
          TextStyle(color: Colors.grey.shade400, fontSize: 11),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta notificación se enviará a TODOS los usuarios activos de la plataforma de forma inmediata.',
              style: TextStyle(
                  color: Colors.amber.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _tipoActual.color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: _tipoActual.color.withOpacity(0.4),
        ),
        onPressed: _loading ? null : _confirmarYEnviar,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(_tipoActual.icon, size: 22),
        label: Text(
          _loading ? 'Enviando...' : 'Enviar a todos',
          style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ── Diálogo de confirmación ──────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final _TipoAlerta tipo;
  final String titulo;
  final String mensaje;

  const _ConfirmDialog({
    required this.tipo,
    required this.titulo,
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Text(tipo.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '¿Enviar alerta?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tipo.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tipo.color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tipo.emoji} $titulo',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tipo.color,
                      fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  mensaje,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.people_rounded,
                  color: Colors.grey.shade500, size: 16),
              const SizedBox(width: 6),
              Text(
                'Se notificará a todos los usuarios activos',
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancelar',
              style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: tipo.color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Enviar ahora'),
        ),
      ],
    );
  }
}

// ── Modelo de tipo de alerta ─────────────────────────────────────────────────
class _TipoAlerta {
  final String   key;
  final String   label;
  final String   emoji;
  final Color    color;
  final IconData icon;
  final String   hint;

  const _TipoAlerta({
    required this.key,
    required this.label,
    required this.emoji,
    required this.color,
    required this.icon,
    required this.hint,
  });
}
