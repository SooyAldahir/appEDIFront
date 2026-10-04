import 'package:flutter/material.dart';

/// Diálogo de "hay una versión nueva".
///
/// Cuando `obligatoria` es true no se puede cerrar de ninguna forma: no hay
/// botón de posponer, tocar fuera no lo cierra y el botón atrás tampoco.
/// Es intencional — en ese estado la app ya no funciona bien contra el
/// backend, y dejar seguir solo produce fallas que el usuario no entiende.
class UpdateDialog extends StatefulWidget {
  final bool obligatoria;
  final String versionNueva;
  final String versionActual;
  final String notas;
  final Future<bool> Function() onActualizar;

  /// null cuando la actualización es obligatoria.
  final Future<void> Function()? onMasTarde;

  const UpdateDialog({
    super.key,
    required this.obligatoria,
    required this.versionNueva,
    required this.versionActual,
    required this.notas,
    required this.onActualizar,
    this.onMasTarde,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  bool _abriendo = false;
  bool _falloAbrir = false;

  Future<void> _actualizar() async {
    setState(() {
      _abriendo = true;
      _falloAbrir = false;
    });

    final ok = await widget.onActualizar();

    if (!mounted) return;
    setState(() {
      _abriendo = false;
      _falloAbrir = !ok;
    });

    // Si la tienda abrió, el diálogo se queda: al volver, el servicio vuelve
    // a consultar y lo cierra solo si ya actualizó. Si era obligatoria y se
    // cerrara aquí, la persona podría volver sin haber actualizado y quedarse
    // dentro de una app que no funciona.
    if (ok && !widget.obligatoria && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _masTarde() async {
    await widget.onMasTarde?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // El botón atrás de Android tampoco la esquiva.
      canPop: !widget.obligatoria,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.obligatoria
                    ? Colors.red.shade50
                    : _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.obligatoria
                    ? Icons.warning_amber_rounded
                    : Icons.system_update_rounded,
                color: widget.obligatoria ? Colors.red.shade700 : _primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.obligatoria
                  ? 'Necesitas actualizar'
                  : 'Hay una versión nueva',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.obligatoria
                  ? 'Esta versión de EDI 301 ya no es compatible. Para seguir '
                      'usando la app necesitas instalar la más reciente.'
                  : 'Ya está disponible una nueva versión de EDI 301 con '
                      'mejoras y correcciones.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            if (widget.notas.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.notas.trim(),
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ],
            if (widget.versionNueva.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Tienes la ${widget.versionActual} · '
                'Disponible la ${widget.versionNueva}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            if (_falloAbrir) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No se pudo abrir la tienda. Búscala manualmente como '
                      '"EDI 301".',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          if (!widget.obligatoria)
            TextButton(
              onPressed: _abriendo ? null : _masTarde,
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
              child: const Text('Más tarde'),
            ),
          ElevatedButton.icon(
            onPressed: _abriendo ? null : _actualizar,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.obligatoria ? _primary : _gold,
              foregroundColor: widget.obligatoria ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: _abriendo
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(
              _abriendo ? 'Abriendo...' : 'Actualizar',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
