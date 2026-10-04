import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';

/// Panel de control del administrador.
///
/// Organizado por **lo que hace cada cosa**, no por el tamaño de la tarjeta.
/// Antes había una fila que repartía el ancho entre todas las tarjetas que le
/// cupieran: con tres se veía bien, pero al agregar Población y Versión
/// quedaron cinco apretadas en un renglón. Ahora cada sección es una
/// cuadrícula que se acomoda sola, así que agregar una opción nueva no
/// descuadra nada.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  static const _navy = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);
  static const _navyL = Color.fromRGBO(30, 85, 135, 1);

  // Lo más usado, y lo único que va destacado a ancho completo.
  static const _primary = _AdminItem(
    label: 'Consultar Familias',
    sub: 'Directorio, detalles y reportes',
    icon: Icons.family_restroom_rounded,
    route: 'get_family',
    gradient: [Color.fromRGBO(19, 67, 107, 1), Color.fromRGBO(10, 40, 75, 1)],
    accent: _gold,
  );

  static const _secciones = <_Seccion>[
    _Seccion('Familias', [
      _AdminItem(
        label: 'Agregar familia',
        sub: 'Nueva familia',
        icon: Icons.add_home_rounded,
        route: 'add_family',
        gradient: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        accent: Color(0xFF82B1FF),
      ),
      _AdminItem(
        label: 'Asignar alumnos',
        sub: 'A familia existente',
        icon: Icons.school_rounded,
        route: 'add_alumns',
        gradient: [Color(0xFF00695C), Color(0xFF004D40)],
        accent: Color(0xFF80CBC4),
      ),
      _AdminItem(
        label: 'Tutor externo',
        sub: 'Sin correo institucional',
        icon: Icons.person_add_alt_1_rounded,
        route: 'add_tutor',
        gradient: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
        accent: Color(0xFFCE93D8),
      ),
      // Va junto a "Tutor externo" porque comparten el problema —gente sin
      // correo institucional— pero son cosas distintas: un alumno a prueba SI
      // es alumno, ocupa lugar de hijo EDI y cuenta en la poblacion.
      _AdminItem(
        label: 'Alumnos a prueba',
        sub: 'Sin matrícula todavía',
        icon: Icons.hourglass_top_rounded,
        route: 'alumnos_prueba',
        gradient: [Color(0xFF00695C), Color(0xFF00382F)],
        accent: Color(0xFF80CBC4),
      ),
      _AdminItem(
        label: 'Renovación de ciclo',
        sub: 'Ventana, solicitudes y vaciado',
        icon: Icons.refresh_rounded,
        route: 'renovaciones_admin',
        gradient: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        accent: Color(0xFFA5D6A7),
      ),
    ]),

    _Seccion('Comunicación', [
      // Se marca como destacada para que resalte con un borde, pero ocupa una
      // celda como las demás: antes era de ancho completo y dominaba la
      // pantalla siendo de las funciones que menos se usan.
      _AdminItem(
        label: 'Alerta instantánea',
        sub: 'Notifica a todos ahora',
        icon: Icons.campaign_rounded,
        route: 'broadcast',
        gradient: [Color(0xFFB71C1C), Color(0xFF7F0000)],
        accent: Color(0xFFFF8A80),
        destacada: true,
      ),
      _AdminItem(
        label: 'Agenda',
        sub: 'Eventos',
        icon: Icons.event_rounded,
        route: 'agenda',
        gradient: [Color(0xFFE65100), Color(0xFFBF360C)],
        accent: Color(0xFFFFCC80),
      ),
      _AdminItem(
        label: 'Encuestas',
        sub: 'Crear, muestrear y ver',
        icon: Icons.poll_rounded,
        route: 'encuestas',
        gradient: [Color(0xFF4527A0), Color(0xFF311B92)],
        accent: Color(0xFFB39DDB),
      ),
      _AdminItem(
        label: 'Cumpleaños',
        sub: 'Pasados, próximos y mensaje',
        icon: Icons.cake_rounded,
        route: 'cumpleaños',
        gradient: [Color(0xFFC62828), Color(0xFFB71C1C)],
        accent: Color(0xFFEF9A9A),
      ),
    ]),

    _Seccion('Reportes y datos', [
      _AdminItem(
        label: 'Reportes PDF',
        sub: 'Exportar familias',
        icon: Icons.picture_as_pdf_rounded,
        route: 'reportes',
        gradient: [Color(0xFF37474F), Color(0xFF263238)],
        accent: Color(0xFFB0BEC5),
      ),
      _AdminItem(
        label: 'Población',
        sub: 'Conteo de usuarios',
        icon: Icons.groups_rounded,
        route: 'poblacion',
        gradient: [Color(0xFF00838F), Color(0xFF006064)],
        accent: Color(0xFF80DEEA),
      ),
    ]),

    _Seccion('Configuración', [
      _AdminItem(
        label: 'Administradores',
        sub: 'Asignar rol de Admin',
        icon: Icons.manage_accounts_rounded,
        route: 'assign_admin',
        gradient: [Color(0xFF4A148C), Color(0xFF2E004F)],
        accent: Color(0xFFCE93D8),
      ),
      _AdminItem(
        label: 'Límite de hijos EDI',
        sub: 'Máximo global por familia',
        icon: Icons.tune_rounded,
        route: 'limite_hijos_edi',
        gradient: [Color(0xFF00695C), Color(0xFF004D40)],
        accent: Color(0xFF80CBC4),
      ),
      _AdminItem(
        label: 'Versión de la app',
        sub: 'Avisar actualización',
        icon: Icons.system_update_rounded,
        route: 'version_app',
        gradient: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        accent: Color(0xFF90CAF9),
      ),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: ResponsiveContent(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                sliver: SliverToBoxAdapter(child: _PrimaryCard(item: _primary)),
              ),

              for (final seccion in _secciones) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                  sliver: SliverToBoxAdapter(
                    child: _TituloSeccion(texto: seccion.titulo),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    // maxCrossAxisExtent en vez de un número fijo de columnas:
                    // en teléfono salen 2, en tableta 3 o 4 según el ancho, sin
                    // que las tarjetas se estiren hasta verse deformes.
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 210,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _GridCard(item: seccion.items[i]),
                      childCount: seccion.items.length,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _navyL],
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'ADMINISTRADOR',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Panel de Control',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gestiona familias, alumnos y más',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modelo ────────────────────────────────────────────────────────────────────

class _Seccion {
  final String titulo;
  final List<_AdminItem> items;
  const _Seccion(this.titulo, this.items);
}

class _AdminItem {
  final String label;
  final String sub;
  final IconData icon;
  final String route;
  final List<Color> gradient;
  final Color accent;

  /// Le pone un borde visible para que salte a la vista sin ocupar más
  /// espacio. Pensado para acciones que hay que encontrar con prisa.
  final bool destacada;

  const _AdminItem({
    required this.label,
    required this.sub,
    required this.icon,
    required this.route,
    required this.gradient,
    required this.accent,
    this.destacada = false,
  });
}

// ── Encabezado de sección ─────────────────────────────────────────────────────

class _TituloSeccion extends StatelessWidget {
  final String texto;
  const _TituloSeccion({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          texto.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Colors.blueGrey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: Colors.blueGrey.shade100),
        ),
      ],
    );
  }
}

// ── Tarjeta destacada (ancho completo) ────────────────────────────────────────

class _PrimaryCard extends StatelessWidget {
  final _AdminItem item;
  const _PrimaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: item.gradient.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: item.accent, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.sub,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de cuadrícula ─────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final _AdminItem item;
  const _GridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: item.destacada
              ? Border.all(color: item.accent.withValues(alpha: 0.85), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: item.gradient.first
                  .withValues(alpha: item.destacada ? 0.5 : 0.35),
              blurRadius: item.destacada ? 16 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.accent, size: 22),
            ),
            const Spacer(),
            Text(
              item.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10.5,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
