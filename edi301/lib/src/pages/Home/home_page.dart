import 'package:edi301/src/pages/Home/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:edi301/src/pages/News/news_page.dart';
import 'package:edi301/src/pages/Family/familiy_page.dart';
import 'package:edi301/src/pages/Search/search_page.dart';
import 'package:edi301/src/pages/Perfil/perfil_page.dart';
import 'package:edi301/src/pages/Admin/admin_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const NewsPage(),
    const FamiliyPage(),
    const SearchPage(),
    const AdminPage(),
    const PerfilPage(),
  ];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context);
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder nos dice cuánto espacio tenemos disponible
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si el ancho es menor a 640px, usamos diseño de celular (barra abajo)
        if (constraints.maxWidth < 640) {
          return _buildMobileLayout();
        }
        // Si es mayor, usamos diseño tablet (barra a la izquierda)
        else {
          return _buildTabletLayout();
        }
      },
    );
  }

  /// DISEÑO CELULAR: Menú abajo
  Widget _buildMobileLayout() {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        selectedItemColor: const Color.fromRGBO(245, 188, 6, 1),
        unselectedItemColor: Colors.white,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: _buildIcon(Icons.newspaper, 0),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(Icons.family_restroom_outlined, 1),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(Icons.person_search, 2),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(Icons.admin_panel_settings, 3),
            label: '',
          ),
          BottomNavigationBarItem(icon: _buildIcon(Icons.person, 4), label: ''),
        ],
      ),
    );
  }

  /// DISEÑO TABLET/WEB: Menú lateral izquierdo (NavigationRail)
  Widget _buildTabletLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.none,
            // Centrar items verticalmente (opcional)
            groupAlignment: 0.0,
            destinations: [
              NavigationRailDestination(
                icon: _buildIcon(Icons.newspaper, 0),
                label: const Text(''),
              ),
              NavigationRailDestination(
                icon: _buildIcon(Icons.family_restroom_outlined, 1),
                label: const Text(''),
              ),
              NavigationRailDestination(
                icon: _buildIcon(Icons.person_search, 2),
                label: const Text(''),
              ),
              NavigationRailDestination(
                icon: _buildIcon(Icons.admin_panel_settings, 3),
                label: const Text(''),
              ),
              NavigationRailDestination(
                icon: _buildIcon(Icons.person, 4),
                label: const Text(''),
              ),
            ],
          ),

          // El contenido ocupa el resto del espacio
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  // Tu función original de iconos (la reutilizamos para ambos diseños)
  Widget _buildIcon(IconData icon, int index) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _selectedIndex == index
            ? const Color.fromRGBO(245, 188, 6, 1) // Amarillo seleccionado
            : Colors.transparent,
      ),
      padding: const EdgeInsets.all(7),
      child: Icon(
        icon,
        color: _selectedIndex == index ? Colors.white : Colors.white70,
      ),
    );
  }
}
