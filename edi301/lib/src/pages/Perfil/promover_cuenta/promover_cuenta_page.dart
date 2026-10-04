import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edi301/core/api_error.dart';
import 'package:edi301/services/alumnos_prueba_api.dart';
import 'package:edi301/services/users_api.dart';

/// "Ya tengo matrícula": el alumno que entró en periodo de prueba completa su
/// cuenta él mismo.
///
/// Por qué existe: la oficina contó que los alumnos no vuelven a sistemas
/// cuando les asignan la matrícula, así que el periodo de prueba se quedaba
/// sin cerrar. Si lo puede hacer desde el teléfono, no tiene que volver.
///
/// El código llega al correo institucional que está declarando, y eso es lo
/// que demuestra que ese correo es suyo. Sin esa prueba, cualquiera con
/// cuenta a prueba podría reclamar el correo de un compañero y quedarse con
/// él.
class PromoverCuentaPage extends StatefulWidget {
  const PromoverCuentaPage({super.key});

  @override
  State<PromoverCuentaPage> createState() => _PromoverCuentaPageState();
}

class _PromoverCuentaPageState extends State<PromoverCuentaPage> {
  static const _navy = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final _api = AlumnosPruebaApi();
  final _usersApi = UsersApi();

  final _matricula = TextEditingController();
  final _correo = TextEditingController();
  final _codigo = TextEditingController();

  int _paso = 0;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _matricula.dispose();
    _correo.dispose();
    _codigo.dispose();
    super.dispose();
  }

  int? get _matriculaValida {
    final m = int.tryParse(_matricula.text.trim());
    return (m != null && m > 0) ? m : null;
  }

  Future<void> _enviarCodigo() async {
    final correo = _correo.text.trim().toLowerCase();
    if (_matriculaValida == null) {
      setState(() => _error = 'Escribe tu matrícula.');
      return;
    }
    if (!correo.contains('@')) {
      setState(() => _error = 'Escribe tu correo institucional.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _usersApi.enviarCodigoVerificacion(correo, proposito: 'PROMOCION');
      if (!mounted) return;
      setState(() {
        _paso = 1;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _cargando = false;
      });
    }
  }

  Future<void> _confirmar() async {
    final codigo = _codigo.text.trim();
    if (codigo.isEmpty) {
      setState(() => _error = 'Escribe el código que te llegó.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _api.promoverme(
        matricula: _matriculaValida!,
        correoInstitucional: _correo.text.trim().toLowerCase(),
        codigo: codigo,
      );

      // La sesión guardada trae la matrícula y el correo viejos. Se borra para
      // que el siguiente arranque los lea del servidor en vez de mostrar datos
      // que ya no son ciertos.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user');
      } catch (_) {}

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('¡Listo!'),
          content: const Text(
            'Tu cuenta ya tiene matrícula y correo institucional. Vuelve a '
            'iniciar sesión para que se actualicen tus datos. Tu correo '
            'personal te sigue sirviendo para entrar.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Ya tengo matrícula'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Entraste a la app durante tu periodo de prueba. Cuando la '
              'universidad te asigne tu matrícula y tu correo institucional, '
              'complétalos aquí y tu cuenta queda como la de cualquier otro '
              'alumno. No hace falta que vayas a sistemas.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 22),
          if (_paso == 0) ..._pasoDatos() else ..._pasoCodigo(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  List<Widget> _pasoDatos() => [
        TextField(
          controller: _matricula,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Tu matrícula',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _correo,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Tu correo institucional',
            hintText: 'nombre.apellido@ulv.edu.mx',
            helperText: 'Te enviaremos un código ahí para confirmar que es tuyo.',
            helperMaxLines: 2,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 22),
        _boton('Enviar código', _enviarCodigo),
      ];

  List<Widget> _pasoCodigo() => [
        Text(
          'Escribe el código que enviamos a ${_correo.text.trim()}.',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _codigo,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, letterSpacing: 8),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 22),
        _boton('Confirmar', _confirmar),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _cargando ? null : _enviarCodigo,
          child: const Text('Reenviar código'),
        ),
        TextButton(
          onPressed: _cargando
              ? null
              : () => setState(() {
                    _paso = 0;
                    _error = null;
                  }),
          child: const Text('Cambiar mis datos'),
        ),
      ];

  Widget _boton(String texto, VoidCallback alPulsar) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _cargando ? null : alPulsar,
          child: _cargando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(texto,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
}
