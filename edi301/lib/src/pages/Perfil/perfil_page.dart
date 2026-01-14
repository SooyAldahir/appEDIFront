import 'dart:async';
import 'dart:convert';
import 'package:edi301/services/estados_api.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/src/pages/Perfil/perfil_widgets.dart';
import 'package:edi301/auth/token_storage.dart';
import 'package:image_picker/image_picker.dart'; // 🔥 1. Importar Image Picker
import 'package:http/http.dart' as http; // 🔥 Importar http para MultipartFile

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  bool _isAlumno = false;
  int? _userId;

  final EstadosApi _estadosApi = EstadosApi();
  final ApiHttp _http = ApiHttp();
  final TokenStorage _storage = TokenStorage();

  // Datos base
  Map<String, dynamic> data = {
    'name': '—',
    'matricula': '—',
    'phone': '—',
    'email': '—',
    'residence': '—',
    'family': '—',
    'address': '—',
    'birthday': '—',
    'avatarUrl':
        '', // Lo dejamos vacío para que el widget decida el placeholder
    'status': 'Activo',
    'grade': '—',
  };

  bool notif = true;
  bool darkMode = false;
  // bool showAvatar = true; // ❌ Ya no se usa
  bool bgRefresh = true;
  bool birthdayReminder = true;

  bool _loading = true;
  final primary = const Color.fromRGBO(19, 67, 107, 1);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // --- 🔥 NUEVA FUNCIÓN PARA SUBIR FOTO ---
  Future<void> _pickAndUploadProfile() async {
    final picker = ImagePicker();
    // Abrir galería
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return; // Usuario canceló

    setState(() => _loading = true);

    try {
      // Obtenemos los datos actuales para re-enviarlos y evitar que se borren
      // (Aunque el backend debería ser robusto, esto es doble seguridad)
      Map<String, String> currentData = {
        'nombre': data['name'].toString().split(
          ' ',
        )[0], // Solo primer nombre aprox
        // Puedes agregar más campos si tu backend lo requiere estrictamente
      };

      // Enviamos al endpoint PUT /api/usuarios/:id
      final stream = await _http.multipart(
        '/api/usuarios/$_userId',
        method: 'PUT',
        files: [await http.MultipartFile.fromPath('foto', image.path)],
        fields: currentData,
      );

      if (stream.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto actualizada con éxito")),
        );
        // Recargamos el perfil para que baje la nueva URL
        await _fetchFromServer();
      } else {
        print("Error subida: ${stream.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al subir la imagen")),
        );
      }
    } catch (e) {
      print("Error upload: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 1) Lee 'user' de SharedPreferences
  Future<void> _hydrateFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user');
      if (raw == null) return;

      final u = jsonDecode(raw) as Map<String, dynamic>;
      String tipo = (u['tipo_usuario'] ?? u['TipoUsuario'] ?? '').toString();

      int id = 0;
      if (u['id_usuario'] != null)
        id = int.tryParse(u['id_usuario'].toString()) ?? 0;
      else if (u['IdUsuario'] != null)
        id = int.tryParse(u['IdUsuario'].toString()) ?? 0;
      else if (u['id'] != null)
        id = int.tryParse(u['id'].toString()) ?? 0;

      String nombre = (u['nombre'] ?? u['Nombre'] ?? '').toString();
      String apellido = (u['apellido'] ?? u['Apellido'] ?? '').toString();

      setState(() {
        _isAlumno = tipo.toUpperCase() == 'ALUMNO';
        _userId = id;

        data = {
          ...data,
          'name': (('$nombre $apellido').trim().isEmpty)
              ? '—'
              : ('$nombre $apellido').trim(),
          'email': (u['correo'] ?? u['E_mail'] ?? '—').toString(),
          'matricula': (u['matricula'] ?? u['Matricula'] ?? '—').toString(),
          'phone': (u['telefono'] ?? u['Telefono'] ?? '—').toString(),
          'residence': (u['residencia'] ?? u['Residencia'] ?? '—').toString(),
          'address': (u['direccion'] ?? u['Direccion'] ?? '—').toString(),
          'birthday': (u['fecha_nacimiento'] ?? u['Fecha_Nacimiento'] ?? '—')
              .toString(),
          'avatarUrl':
              (u['foto_perfil'] ?? u['FotoPerfil'] ?? data['avatarUrl'])
                  .toString(),
          'status': (u['estado'] ?? u['Estado'] ?? 'Activo').toString(),
          'grade': (u['carrera'] ?? '—').toString(),
          'family': (u['nombre_familia'] ?? '—').toString(),
        };
      });
    } catch (e) {
      print("Error cargando perfil local: $e");
    }
  }

  Future<void> _fetchFromServer() async {
    try {
      // ... Lógica para obtener ID ...
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user');
      if (raw == null) return;
      final uLocal = jsonDecode(raw) as Map<String, dynamic>;
      final id = uLocal['IdUsuario'] ?? uLocal['id_usuario'] ?? _userId;

      if (id == null) return;

      final res = await _http.getJson('/api/usuarios/$id');
      if (res.statusCode >= 400) return;

      final x = jsonDecode(res.body) as Map<String, dynamic>;

      String nombre = (x['nombre'] ?? x['Nombre'] ?? uLocal['nombre'] ?? '')
          .toString();
      String apellido =
          (x['apellido'] ?? x['Apellido'] ?? uLocal['apellido'] ?? '')
              .toString();
      String colorHex = (x['color_estado'] ?? '#13436B').toString();

      // Fix URL de avatar
      String avatar = (x['foto_perfil'] ?? x['FotoPerfil'] ?? data['avatarUrl'])
          .toString();
      if (avatar.isNotEmpty && !avatar.startsWith('http')) {
        avatar = '${ApiHttp.baseUrl}$avatar';
      }

      setState(() {
        data = {
          ...data,
          'name': (('$nombre $apellido').trim().isEmpty)
              ? data['name']
              : ('$nombre $apellido').trim(),
          'email': (x['correo'] ?? x['E_mail'] ?? data['email']).toString(),
          'matricula': (x['matricula'] ?? x['Matricula'] ?? data['matricula'])
              .toString(),
          'phone': (x['telefono'] ?? x['Telefono'] ?? data['phone']).toString(),
          'residence': (x['residencia'] ?? x['Residencia'] ?? data['residence'])
              .toString(),
          'address': (x['direccion'] ?? x['Direccion'] ?? data['address'])
              .toString(),
          'birthday':
              (x['fecha_nacimiento'] ??
                      x['Fecha_Nacimiento'] ??
                      data['birthday'])
                  .toString(),
          'avatarUrl': avatar,
          'status': (x['estado'] ?? x['Estado'] ?? data['status']).toString(),
          'statusColorHex': colorHex,
          'grade': (x['carrera'] ?? data['grade']).toString(),
          'family': (x['nombre_familia'] ?? data['family']).toString(),
        };
      });
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    await _hydrateFromLocal();
    await _fetchFromServer();
    if (mounted) setState(() => _loading = false);
  }

  // Función Logout
  Future<void> _handleLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _http.postJson('/api/auth/logout');
    } catch (_) {}
    await _storage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');

    if (mounted)
      Navigator.of(context).pushNamedAndRemoveUntil('login', (_) => false);
  }

  // ... (Helpers s(), isInternal, _statusColor, _showEstadoSelector, _updateEstado se quedan igual) ...
  String s(String k, [String d = '—']) {
    final v = data[k];
    if (v == null) return d;
    final t = v.toString().trim();
    return t.isEmpty ? d : t;
  }

  bool get isInternal => s('residence').toLowerCase().startsWith('intern');
  Color _statusColor(String st) {
    final low = st.toLowerCase();
    if (low.contains('inac') || low.contains('baja') || low.contains('suspend'))
      return Colors.red;
    if (low.contains('pend') || low.contains('proce')) return Colors.orange;
    return Colors.green;
  }

  void _showEstadoSelector() async {
    if (!_isAlumno || _userId == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final catalogo = await _estadosApi.getCatalogo();
    if (!mounted) return;
    Navigator.pop(context);
    if (catalogo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los estados')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Actualizar mi estado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: catalogo.length,
                itemBuilder: (context, index) {
                  final item = catalogo[index];
                  return ListTile(
                    leading: Icon(
                      Icons.circle,
                      size: 16,
                      color: hexToColor(item['color'] ?? '#000000'),
                    ),
                    title: Text(item['descripcion']),
                    onTap: () async {
                      Navigator.pop(context);
                      await _updateEstado(item['id_cat_estado']);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateEstado(int idCatEstado) async {
    setState(() => _loading = true);
    final success = await _estadosApi.updateEstado(_userId!, idCatEstado);
    if (success) {
      await _fetchFromServer();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estado actualizado correctamente')),
        );
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar estado')),
        );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        : _buildContent(context);

    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: NestedScrollView(
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              title: const Text('Mi perfil'),
              backgroundColor: primary,
              automaticallyImplyLeading: false,
              elevation: 0,
              floating: true,
              snap: true,
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout),
                  onPressed: _handleLogout,
                ),
              ],
            ),
          ],
          body: content,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final p = primary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            HeaderCard(
              name: s('name'),
              family: s('family'),
              residence: s('residence'),
              status: s('status', 'Activo'),
              avatarUrl: s('avatarUrl'),
              primary: p,
              statusColor: data['statusColorHex'] != null
                  ? hexToColor(data['statusColorHex'])
                  : _statusColor(s('status', 'Activo')),

              // 🔥 CONECTAMOS LA NUEVA FUNCIÓN
              onEditAvatar: _pickAndUploadProfile,

              onTapStatus: _isAlumno ? _showEstadoSelector : null,
            ),
            const SizedBox(height: 12),

            SectionCard(
              title: 'Datos',
              primary: p,
              children: [
                InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Matrícula',
                  value: s('matricula'),
                ),
                InfoRow(
                  icon: Icons.school_outlined,
                  label: 'Programa',
                  value: s('grade'),
                ),
                InfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Cumpleaños',
                  value: s('birthday'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SectionCard(
              title: 'Contacto',
              primary: p,
              children: [
                InfoRow(
                  icon: Icons.call_outlined,
                  label: 'Teléfono',
                  value: s('phone'),
                ),
                InfoRow(
                  icon: Icons.mail_outline,
                  label: 'Correo',
                  value: s('email'),
                ),
                if (!isInternal)
                  InfoRow(
                    icon: Icons.home_outlined,
                    label: 'Dirección',
                    value: s('address'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            SettingsCard(
              primary: p,
              notif: notif,
              darkMode: darkMode,
              // showAvatar: showAvatar, // ❌ Eliminado
              bgRefresh: bgRefresh,
              birthdayReminder: birthdayReminder,
              onChanged: (k, v) => setState(() {
                switch (k) {
                  case 'notif':
                    notif = v;
                    break;
                  case 'dark':
                    darkMode = v;
                    break;
                  // case 'avatar': showAvatar = v; break;
                  case 'bg':
                    bgRefresh = v;
                    break;
                  case 'bd':
                    birthdayReminder = v;
                    break;
                }
              }),
            ),
          ],
        ),
      ),
    );
  }
}

Color hexToColor(String hexString, {Color defaultColor = Colors.blue}) {
  try {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return defaultColor;
  }
}
