import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/src/pages/Home/home_controller.dart';
import 'package:edi301/src/pages/News/news_page.dart';
import 'package:edi301/src/pages/Family/familiy_page.dart';
import 'package:edi301/src/pages/Search/search_page.dart';
import 'package:edi301/src/pages/Perfil/perfil_page.dart';
import 'package:edi301/src/pages/Admin/admin_page.dart';
import 'package:edi301/src/pages/Admin/agenda/agenda_page.dart';
import 'package:edi301/src/pages/Chat/my_chats_page.dart';
import 'package:edi301/src/pages/Family/chat_family_page.dart';
import 'package:edi301/src/pages/Encuestas/encuestas_page.dart';
import 'package:edi301/src/widgets/liquid_glass_nav.dart';
import 'package:edi301/services/biometric_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();
  final PageController _pageCtrl = PageController();

  int _selectedIndex = 0;
  String _userRole = '';
  List<Map<String, dynamic>> _menuOptions = [];

  /// La barra inferior se encoge al bajar por el contenido (estilo Instagram).
  bool _navCollapsed = false;

  /// Desplazamiento acumulado en la dirección actual. Sirve de umbral para
  /// que un movimiento mínimo del dedo no haga parpadear la barra.
  double _scrollAccum = 0;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context);
      _ofrecerBiometricoUnaVez();
    });
  }

  /// Se ofrece el desbloqueo biométrico UNA sola vez, la primera vez que se
  /// llega a home con sesión iniciada. Si dice que no, no se vuelve a insistir:
  /// queda el interruptor en Perfil.
  Future<void> _ofrecerBiometricoUnaVez() async {
    final bio = BiometricService();
    if (await bio.wasPromptShown()) return;
    if (await bio.isEnabled()) return;
    if (!await bio.isAvailable()) return;

    // Un respiro para no encimarse con otros diálogos de arranque.
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final nombre = await bio.friendlyName();
    if (!mounted) return;
    await bio.markPromptShown();

    final aceptar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              nombre == 'Face ID'
                  ? Icons.face_retouching_natural
                  : Icons.fingerprint,
              color: const Color.fromRGBO(19, 67, 107, 1),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Entrar con $nombre')),
          ],
        ),
        content: Text(
          'Puedes abrir EDI 301 con tu $nombre en lugar de escribir tu '
          'contraseña cada vez. Podrás desactivarlo cuando quieras desde tu perfil.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Ahora no',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );

    if (aceptar != true || !mounted) return;

    // Se exige pasar el biométrico una vez antes de darlo por activado.
    final resultado = await bio.authenticate(
      reason: 'Confirma tu $nombre para activar el acceso rápido',
    );
    if (!mounted) return;

    if (resultado == BiometricResult.success) {
      await bio.setEnabled(true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listo: la próxima vez entras con tu $nombre.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    String rol = '';
    if (userStr != null) {
      final user = jsonDecode(userStr);
      rol = user['nombre_rol'] ?? user['rol'] ?? '';
    }
    if (mounted) {
      setState(() {
        _userRole = rol;
        _menuOptions = _getMenuOptions(rol);
      });
    }
  }

  /* Future<void> _verificarYMostrarEncuesta() async {
    final prefs = await SharedPreferences.getInstance();
    final yaMostrada = prefs.getBool('encuesta_mostrada') ?? false;
    if (yaMostrada) return;
    int openCount = prefs.getInt('app_open_count') ?? 0;
    openCount++;
    await prefs.setInt('app_open_count', openCount);
    if (openCount >= 2 && mounted) _mostrarDialogoEncuesta(context);
  } */

  /* void _mostrarDialogoEncuesta(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.assignment, color: Color.fromRGBO(19, 67, 107, 1)),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                '¡Tu opinión nos importa!',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Ayúdanos a mejorar respondiendo esta breve encuesta. No te tomará más de 2 minutos.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('app_open_count', 0);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text(
              'Más tarde',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('encuesta_mostrada', true);
              if (ctx.mounted) Navigator.of(ctx).pop();
              final uri = Uri.parse(
                'https://docs.google.com/forms/d/e/1FAIpQLSfmPuyryfjKzi372NfoNHPHrwyduHVrILEfvNG8g9JLEVxS5w/viewform?usp=sharing&ouid=101381466647283644158',
              );
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Error al abrir la encuesta: $e');
              }
            },
            child: const Text(
              'Responder',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  } */

  Widget _getPageFromRoute(String route) {
    switch (route) {
      case 'news':
        return const NewsPage();
      case 'chat':
        return const MyChatsPage();
      case 'family':
        return const FamiliyPage();
      case 'search':
        return const SearchPage();
      case 'agenda':
        return const AgendaPage();
      case 'admin':
        return const AdminPage();
      case 'perfil':
        return const PerfilPage();
      case 'encuestas':
        return const EncuestasPage();
      default:
        return const Center(child: Text('Página no encontrada'));
    }
  }

  List<Map<String, dynamic>> _getMenuOptions(String rol) {
    final all = [
      {'ruta': 'news', 'icon': Icons.newspaper, 'label': 'Noticias'},
      {'ruta': 'chat', 'icon': Icons.chat_bubble, 'label': 'Mensajes'},
      {'ruta': 'family', 'icon': Icons.family_restroom, 'label': 'Familia'},
      {'ruta': 'search', 'icon': Icons.person_search, 'label': 'Buscar'},
      {'ruta': 'agenda', 'icon': Icons.calendar_month, 'label': 'Agenda'},
      {'ruta': 'encuestas', 'icon': Icons.poll, 'label': 'Encuestas'},
      {'ruta': 'admin', 'icon': Icons.admin_panel_settings, 'label': 'Admin'},
      {'ruta': 'perfil', 'icon': Icons.person, 'label': 'Perfil'},
    ];

    // El admin ya NO lleva Agenda ni Encuestas en la barra de navegación:
    // ambas viven dentro del Panel de Control para no saturar la barra.
    if (rol == 'Admin') {
      return all
          .where((op) => !['agenda', 'encuestas'].contains(op['ruta']))
          .toList();
    }

    if ([
      'Padre',
      'Madre',
      'Tutor',
      'PapaEDI',
      'MamaEDI',
      'Hijo',
      'HijoEDI',
      'Alumno',
      'Estudiante',
    ].contains(rol)) {
      return all
          .where(
            (op) => ['news', 'chat', 'family', 'perfil'].contains(op['ruta']),
          )
          .toList();
    }

    return [];
  }

  // ── Encoger / expandir la barra según el scroll ──────────────────────────
  /// Escucha el scroll de CUALQUIER lista dentro del PageView: las
  /// notificaciones burbujean hacia arriba, así que no hay que tocar cada
  /// pantalla. Solo se atiende el eje vertical (el PageView es horizontal y
  /// los carruseles internos también).
  bool _handleScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;

    if (n is ScrollUpdateNotification) {
      // Pegado al tope siempre se ve completa.
      if (n.metrics.pixels <= 8) {
        _scrollAccum = 0;
        _setNavCollapsed(false);
        return false;
      }

      final double delta = n.scrollDelta ?? 0;
      if (delta == 0) return false;

      // Si cambia la dirección, se reinicia el acumulado.
      _scrollAccum = (_scrollAccum.sign == delta.sign)
          ? _scrollAccum + delta
          : delta;

      if (_scrollAccum > 28) _setNavCollapsed(true);
      if (_scrollAccum < -28) _setNavCollapsed(false);
    }
    return false;
  }

  void _setNavCollapsed(bool value) {
    if (_navCollapsed == value || !mounted) return;
    // Si la notificación llegó mientras el framework construye o hace layout,
    // un setState directo revienta. En ese caso se difiere al siguiente frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _navCollapsed != value) {
          setState(() => _navCollapsed = value);
        }
      });
      return;
    }
    setState(() => _navCollapsed = value);
  }

  // ── Navigation: keeps PageView and BottomNav in sync ─────────────────────
  void _onNavTap(int index) {
    _scrollAccum = 0;
    setState(() {
      _selectedIndex = index;
      // Al cambiar de sección la barra vuelve a su tamaño completo.
      _navCollapsed = false;
    });

    // En tablet y escritorio NO se construye el PageView: ese layout usa el
    // riel lateral y pinta la página seleccionada directamente. El controlador
    // no está adjunto a nada, y animateToPage revienta con
    // "PageController is not attached to a PageView".
    if (_pageCtrl.hasClients) {
      _pageCtrl.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    _scrollAccum = 0;
    setState(() {
      _selectedIndex = index;
      _navCollapsed = false;
    });
  }

  /// Convierte las opciones del menú en destinos para la navegación de vidrio,
  /// marcando con punto dorado las que tienen mensajes sin leer.
  List<GlassNavItem> _buildNavItems(int unreadChats, int unreadFamily) {
    return _menuOptions.map((op) {
      final ruta = op['ruta'] as String;
      final hasUnread =
          (ruta == 'chat' && unreadChats > 0) ||
          (ruta == 'family' && unreadFamily > 0);
      return GlassNavItem(
        icon: op['icon'] as IconData,
        label: op['label'] as String,
        showDot: hasUnread,
      );
    }).toList();
  }

  /// Reserva el alto de la barra flotante para el contenido de las páginas.
  ///
  /// IMPORTANTE: el `context` debe venir de DENTRO del SafeArea. El SafeArea
  /// ya consumió el padding superior y lo puso en cero para sus hijos; si se
  /// toma el MediaQuery de afuera se reinyecta ese padding y los AppBar de
  /// cada página quedan separados del borde por el alto de la barra de estado
  /// dos veces.
  Widget _withNavInset(BuildContext innerContext, Widget child) {
    final mq = MediaQuery.of(innerContext);
    final inset = LiquidGlassNavBar.heightWithInsets(innerContext);
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(bottom: inset),
        viewPadding: mq.viewPadding.copyWith(bottom: inset),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_menuOptions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_selectedIndex >= _menuOptions.length) _selectedIndex = 0;

    return ValueListenableBuilder<int>(
      valueListenable: MyChatsPage.totalUnread,
      builder: (context, unreadChats, _) {
        return ValueListenableBuilder<int>(
          valueListenable: ChatFamilyPage.familyUnread,
          builder: (context, unreadFamily, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                // ── Móvil: PageView + barra de vidrio flotante ────────────
                if (constraints.maxWidth < 640) {
                  return Scaffold(
                    // extendBody: el contenido pasa por debajo de la barra,
                    // que es justo lo que el desenfoque necesita para verse
                    // como vidrio.
                    extendBody: true,
                    body: SafeArea(
                      bottom: false,
                      // Builder para leer el MediaQuery YA recortado por el
                      // SafeArea; si no, se duplica el espacio de arriba.
                      child: Builder(
                        builder: (innerContext) => _withNavInset(
                          innerContext,
                          NotificationListener<ScrollNotification>(
                            onNotification: _handleScroll,
                            child: PageView(
                              controller: _pageCtrl,
                              onPageChanged: _onPageChanged,
                              children: _menuOptions
                                  .map(
                                    (op) => _getPageFromRoute(
                                      op['ruta'] as String,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomNavigationBar: LiquidGlassNavBar(
                      items: _buildNavItems(unreadChats, unreadFamily),
                      currentIndex: _selectedIndex,
                      collapsed: _navCollapsed,
                      onTap: _onNavTap,
                    ),
                  );
                }

                // ── Tablet/Escritorio: riel lateral de vidrio ─────────────
                final currentPage = _getPageFromRoute(
                  _menuOptions[_selectedIndex]['ruta'] as String,
                );

                return Scaffold(
                  body: Row(
                    children: [
                      LiquidGlassNavRail(
                        items: _buildNavItems(unreadChats, unreadFamily),
                        currentIndex: _selectedIndex,
                        onTap: _onNavTap,
                      ),
                      Expanded(child: currentPage),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
