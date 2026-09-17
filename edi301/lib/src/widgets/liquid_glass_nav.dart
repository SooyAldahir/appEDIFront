// lib/src/widgets/liquid_glass_nav.dart
//
// Navegación con efecto "liquid glass": una superficie translúcida que
// desenfoca el contenido que pasa por debajo, con borde de luz, brillo
// especular en la parte superior y una píldora de vidrio que se desliza
// detrás del ítem activo.
//
// El ítem activo se marca con vidrio esmerilado (blanco translúcido), no con
// color sólido: el resaltado tiene que sentirse parte del mismo material.
// El dorado se reserva para el punto de "no leído", donde sí hace falta que
// salte a la vista.
//
// La barra inferior se encoge al hacer scroll hacia abajo y vuelve a su
// tamaño al subir, al estilo de Instagram (ver `collapsed`).

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

const Color kGlassNavy = Color.fromRGBO(19, 67, 107, 1);
const Color kGlassGold = Color.fromRGBO(245, 188, 6, 1);

/// Un destino de navegación.
class GlassNavItem {
  final IconData icon;
  final String label;

  /// Punto dorado de "no leído" sobre el ícono.
  final bool showDot;

  const GlassNavItem({
    required this.icon,
    required this.label,
    this.showDot = false,
  });
}

// ── Barra inferior ───────────────────────────────────────────────────────────

class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.collapsed = false,
    this.base = kGlassNavy,
    this.dotColor = kGlassGold,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// `true` mientras el usuario baja por el contenido: la barra se encoge,
  /// se angosta y esconde las etiquetas.
  final bool collapsed;

  /// Color de la superficie de vidrio.
  final Color base;

  /// Color del punto de "no leído".
  final Color dotColor;

  static const double _expandedHeight = 62;
  static const double _collapsedHeight = 46;
  static const double _expandedMargin = 14;
  static const double _collapsedMargin = 38;
  static const double _bottomGap = -10;
  static const double _radius = 30;

  /// Alto que la barra reserva sobre el contenido. Se calcula siempre con el
  /// tamaño expandido para que el contenido no salte mientras se hace scroll.
  static double heightWithInsets(BuildContext context) =>
      _expandedHeight + _bottomGap + MediaQuery.of(context).viewPadding.bottom;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    // t = 0 → expandida, t = 1 → encogida. Se anima de forma continua para
    // que el cambio de tamaño se sienta elástico y no a saltos.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: collapsed ? 1 : 0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final height = lerpDouble(_expandedHeight, _collapsedHeight, t)!;
        final margin = lerpDouble(_expandedMargin, _collapsedMargin, t)!;
        final radius = lerpDouble(_radius, _collapsedHeight / 2, t)!;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            margin,
            // Al encogerse deja el hueco del alto que ya no ocupa, para que
            // la barra no “brinque” hacia abajo.
            _expandedHeight - height,
            margin,
            _bottomGap + bottomInset,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            // El desenfoque es lo que convierte la barra en vidrio: toma lo
            // que haya detrás (el contenido de la página) y lo difumina.
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      base.withValues(alpha: 0.82),
                      base.withValues(alpha: 0.60),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  // expand: los hijos ocupan todo el alto, si no la fila de
                  // botones se pegaría arriba y la píldora quedaría enana.
                  fit: StackFit.expand,
                  children: [
                    // Brillo especular: el reflejo que da la sensación de vidrio.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: height * 0.55,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(radius),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.20),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final n = items.length;
                          final itemW = constraints.maxWidth / n;
                          final index = currentIndex < 0
                              ? 0
                              : (currentIndex >= n ? n - 1 : currentIndex);

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // Píldora de vidrio que se desliza al ítem activo.
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 340),
                                curve: Curves.easeOutCubic,
                                left: itemW * index + 4,
                                top: 6,
                                bottom: 6,
                                width: math.max(0.0, itemW - 8),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      lerpDouble(20, 16, t)!,
                                    ),
                                    // Vidrio esmerilado, no color sólido.
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.30),
                                        Colors.white.withValues(alpha: 0.12),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.42,
                                      ),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                // stretch: cada botón ocupa todo el alto, así
                                // el área táctil es la píldora completa.
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (int i = 0; i < n; i++)
                                    Expanded(
                                      child: _GlassNavButton(
                                        item: items[i],
                                        selected: i == index,
                                        collapseT: t,
                                        dotColor: dotColor,
                                        onTap: () => onTap(i),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlassNavButton extends StatelessWidget {
  const _GlassNavButton({
    required this.item,
    required this.selected,
    required this.collapseT,
    required this.dotColor,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;

  /// 0 = barra expandida, 1 = barra encogida.
  final double collapseT;
  final Color dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Activo: blanco pleno. Inactivo: el mismo blanco, apagado. Así el
    // resaltado se lee como luz sobre el vidrio y no como otro color.
    final color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.62);

    final iconSize = lerpDouble(22, 20, collapseT)!;
    final labelOpacity = (1 - collapseT * 1.8).clamp(0.0, 1.0);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                child: _IconWithDot(
                  icon: item.icon,
                  color: color,
                  showDot: item.showDot,
                  dotColor: dotColor,
                  size: iconSize,
                ),
              ),
              // La etiqueta se colapsa por alto (heightFactor) además de
              // desvanecerse, para que el ícono quede centrado al encoger.
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: (1 - collapseT).clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: labelOpacity,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: selected ? 10.5 : 9.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: color,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconWithDot extends StatelessWidget {
  const _IconWithDot({
    required this.icon,
    required this.color,
    required this.showDot,
    required this.dotColor,
    this.size = 22,
  });

  final IconData icon;
  final Color color;
  final bool showDot;
  final Color dotColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!showDot) return Icon(icon, color: color, size: size);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: size),
        Positioned(
          right: -3,
          top: -3,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Riel lateral (tablet / escritorio) ───────────────────────────────────────

/// Riel de navegación como PÍLDORA FLOTANTE, no como barra de borde a borde.
///
/// Antes esto envolvía un `NavigationRail`, que por diseño ocupa todo el alto
/// de la pantalla: en una tablet se veía como un muro pegado al costado y el
/// redondeo de las esquinas ni se notaba. Ahora la superficie se ajusta al
/// contenido, va centrada verticalmente y queda separada de los bordes, igual
/// que la barra inferior del teléfono.
class LiquidGlassNavRail extends StatelessWidget {
  const LiquidGlassNavRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.base = kGlassNavy,
    this.dotColor = kGlassGold,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color base;
  final Color dotColor;

  static const double _width = 78;
  static const double _radius = 30;
  static const double _margin = 14;

  /// Ancho total que el riel ocupa en la fila, márgenes incluidos.
  static double widthWithMargins() => _width + _margin * 2;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final safe = MediaQuery.of(context).viewPadding;
    final index = currentIndex < 0
        ? 0
        : (currentIndex >= items.length ? items.length - 1 : currentIndex);

    return Padding(
      padding: EdgeInsets.only(
        left: _margin + safe.left,
        right: _margin,
        top: _margin + safe.top,
        bottom: _margin + safe.bottom,
      ),
      // Center + mainAxisSize.min: la píldora mide lo que miden sus botones y
      // se queda a media altura, en vez de estirarse de arriba a abajo.
      child: Center(
        child: SizedBox(
          width: _width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      base.withValues(alpha: 0.82),
                      base.withValues(alpha: 0.60),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                // Si la pantalla es muy baja (un teléfono acostado) los botones
                // se desplazan en vez de desbordar.
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < items.length; i++)
                          _GlassRailButton(
                            item: items[i],
                            selected: i == index,
                            dotColor: dotColor,
                            onTap: () => onTap(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassRailButton extends StatelessWidget {
  const _GlassRailButton({
    required this.item,
    required this.selected,
    required this.dotColor,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final Color dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.62);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // Mismo vidrio esmerilado que marca el ítem activo abajo.
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.30),
                        Colors.white.withValues(alpha: 0.12),
                      ],
                    )
                  : null,
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.42)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  child: _IconWithDot(
                    icon: item.icon,
                    color: color,
                    showDot: item.showDot,
                    dotColor: dotColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
