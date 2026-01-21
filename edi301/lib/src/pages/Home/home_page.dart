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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();
  int _selectedIndex = 0;
  String _userRole = '';
  List<Map<String, dynamic>> _menuOptions = [];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context);
    });
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
      default:
        return const Center(child: Text("Página no encontrada"));
    }
  }

  List<Map<String, dynamic>> _getMenuOptions(String rol) {
    final allOptions = [
      {'ruta': 'news', 'icon': Icons.newspaper, 'label': 'Noticias'},
      {'ruta': 'chat', 'icon': Icons.chat_bubble, 'label': 'Mensajes'},
      {'ruta': 'family', 'icon': Icons.family_restroom, 'label': 'Familia'},
      {'ruta': 'search', 'icon': Icons.person_search, 'label': 'Buscar'},
      {'ruta': 'agenda', 'icon': Icons.calendar_month, 'label': 'Agenda'},
      {'ruta': 'admin', 'icon': Icons.admin_panel_settings, 'label': 'Admin'},
      {'ruta': 'perfil', 'icon': Icons.person, 'label': 'Perfil'},
    ];

    if (rol == 'Admin') {
      return allOptions;
    } else if ([
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
      return allOptions
          .where(
            (op) => ['news', 'chat', 'family', 'perfil'].contains(op['ruta']),
          )
          .toList();
    }

    return [];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_menuOptions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_selectedIndex >= _menuOptions.length) _selectedIndex = 0;

    final currentRoute = _menuOptions[_selectedIndex]['ruta'];
    final currentPage = _getPageFromRoute(currentRoute);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Scaffold(
            body: currentPage,
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
              selectedItemColor: const Color.fromRGBO(245, 188, 6, 1),
              unselectedItemColor: Colors.white,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: _menuOptions.map((op) {
                return BottomNavigationBarItem(
                  icon: Icon(op['icon'] as IconData),
                  label: op['label'] as String,
                );
              }).toList(),
            ),
          );
        } else {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  selectedLabelTextStyle: const TextStyle(
                    color: Color.fromRGBO(245, 188, 6, 1),
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: Colors.white,
                  ),
                  selectedIconTheme: const IconThemeData(
                    color: Color.fromRGBO(245, 188, 6, 1),
                  ),
                  unselectedIconTheme: const IconThemeData(color: Colors.white),
                  destinations: _menuOptions.map((op) {
                    return NavigationRailDestination(
                      icon: Icon(op['icon'] as IconData),
                      label: Text(op['label'] as String),
                    );
                  }).toList(),
                ),
                Expanded(child: currentPage),
              ],
            ),
          );
        }
      },
    );
  }
}
