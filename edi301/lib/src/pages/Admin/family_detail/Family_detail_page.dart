import 'package:edi301/services/search_api.dart' show UserMini;
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/services/socket_service.dart';
import 'package:edi301/services/members_api.dart';
import 'package:edi301/services/publicaciones_api.dart';
import 'package:edi301/src/pages/Admin/add_alumns/add_alumns_controller.dart';
import 'package:edi301/src/pages/Admin/reportes/reporte_familia_individual_service.dart';
import 'package:edi301/src/pages/Admin/family_detail/edit_family_page.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

class FamilyDetailPage extends StatefulWidget {
  const FamilyDetailPage({super.key});

  @override
  State<FamilyDetailPage> createState() => _FamilyDetailPageState();
}

class _FamilyDetailPageState extends State<FamilyDetailPage>
    with SingleTickerProviderStateMixin {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final SocketService _socketService = SocketService();
  final _membersApi = MembersApi();
  final _pubApi = PublicacionesApi();
  final _reporteService = ReporteFamiliaIndividualService();
  final _familiaApi = FamiliaApi();

  bool _realtimeSetup = false;
  int? _rtFamilyId;

  /// Eventos de familia que obligan a recargar el detalle.
  static const List<String> _realtimeEvents = [
    'miembro_agregado',
    'miembro_eliminado',
    'miembros_actualizados',
    'nuevos_alumnos_asignados',
  ];
  Family? _family;
  bool _isLoading = true;
  String? _error;

  // Publicaciones
  List<dynamic> _posts = [];
  bool _postsLoading = false;

  // Tab controller
  late TabController _tabController;

  // PDF export state
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _onFamilyRealtimeEvent(dynamic _) {
    final fid = _rtFamilyId;
    if (mounted && fid != null) _fetchFamilyDetails(fid);
  }

  @override
  void dispose() {
    // Antes esta pantalla nunca soltaba la sala ni los listeners: la
    // referencia a `familia_X` quedaba viva para siempre y el chat familiar
    // ya no lograba salir de la sala al cerrarse.
    for (final ev in _realtimeEvents) {
      _socketService.off(ev, _onFamilyRealtimeEvent);
    }
    if (_rtFamilyId != null) {
      _socketService.leaveRoom('familia_$_rtFamilyId');
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      final args = ModalRoute.of(context)!.settings.arguments;
      int? familyId;
      if (args is Family) {
        familyId = args.id;
      } else if (args is int) {
        familyId = args;
      }
      if (familyId != null) {
        final int fid = familyId;
        if (!_realtimeSetup || _rtFamilyId != familyId) {
          // Si ya se estaba escuchando otra familia, soltamos esa sala.
          if (_rtFamilyId != null && _rtFamilyId != fid) {
            _socketService.leaveRoom('familia_$_rtFamilyId');
          }
          _socketService.joinFamilyRoom(fid);
          // `_socketService.on` es seguro aunque el socket todavía no exista:
          // la conexión se crea de forma asíncrona (hay que leer el token) y
          // acceder a `.socket` directo lanzaba StateError.
          for (final ev in _realtimeEvents) {
            _socketService.off(ev, _onFamilyRealtimeEvent);
            _socketService.on(ev, _onFamilyRealtimeEvent);
          }
          _realtimeSetup = true;
          _rtFamilyId = fid;
        }
        _fetchFamilyDetails(fid);
      } else {
        setState(() {
          _isLoading = false;
          _error = 'ID de familia no encontrado.';
        });
      }
    }
  }

  Future<void> _fetchFamilyDetails(int familyId) async {
    try {
      final api = FamiliaApi();
      final familyData = await api.getById(familyId);
      if (mounted) {
        setState(() {
          _family = Family.fromJson(familyData!);
          _isLoading = false;
        });
      }
      await _fetchPosts(familyId);
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _fetchPosts(int familyId) async {
    setState(() => _postsLoading = true);
    try {
      final res = await _pubApi.getPostsFamilia(familyId, limit: 100);
      final data = res['data'] as List? ?? [];
      if (mounted) setState(() => _posts = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_family == null || _exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      await _reporteService.generarYAbrir(_family!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar el PDF. Inténtalo de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<bool> _showDeleteDialog(String memberName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Quitar a $memberName de esta familia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleDeleteMember(FamilyMember member) async {
    final confirmed = await _showDeleteDialog(member.fullName);
    if (!confirmed || !mounted) return;
    try {
      await _membersApi.removeMember(member.idMiembro);
      setState(() {
        // Cada rol se quita de SU propia lista; antes cualquier tipo que no
        // fuera HIJO ni TIO_EDI se borraba de los alumnos asignados.
        switch (member.tipoMiembro) {
          case MemberType.hijoSanguineo:
            _family!.householdChildren.removeWhere(
              (m) => m.idMiembro == member.idMiembro,
            );
            break;
          case MemberType.tioEdi:
            _family!.uncles.removeWhere((m) => m.idMiembro == member.idMiembro);
            break;
          case MemberType.alumnoEdi:
            _family!.assignedStudents.removeWhere(
              (m) => m.idMiembro == member.idMiembro,
            );
            break;
          case MemberType.padre:
          case MemberType.madre:
            _family!.parentMembers.removeWhere(
              (m) => m.idMiembro == member.idMiembro,
            );
            break;
          default:
            _family!.otherMembers.removeWhere(
              (m) => m.idMiembro == member.idMiembro,
            );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Miembro quitado.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Hogar children ───────────────────────────────────────────────────────────
  Widget _buildHogarChildrenSection(Family fam) {
    final kids = fam.hogarChildren;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.child_care, color: Color(0xFF1A5276)),
        title: const Text(
          'Niños del hogar sin cuenta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          if (kids.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                'Sin niños sin cuenta registrados.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...kids.map(
              (h) => ListTile(
                dense: true,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD6EAF8),
                  child: Icon(
                    Icons.child_care,
                    color: Color(0xFF1A5276),
                    size: 18,
                  ),
                ),
                title: Text(h.fullName),
                subtitle: h.fechaNacimiento != null
                    ? Text('Nac: ${h.fechaNacimiento}')
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _handleDeleteHogarChild(h),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteHogarChild(HogarChild h) async {
    final confirmed = await _showDeleteDialog(h.fullName);
    if (!confirmed || !mounted) return;
    try {
      await _familiaApi.deleteHogarChild(h.idHijo!);
      setState(() {
        _family!.hogarChildren.removeWhere((c) => c.idHijo == h.idHijo);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Niño quitado.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── URL helper ───────────────────────────────────────────────────────────────
  String _absUrl(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '';
    var s = raw.trim();
    if (s.startsWith('http')) return s;
    if (!s.startsWith('/')) s = '/$s';
    return '${ApiHttp.baseUrl}$s';
  }

  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error!, textAlign: TextAlign.center)),
      );
    }

    final fam = _family!;

    return Scaffold(
      appBar: AppBar(
        title: Text(fam.familyName),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        actions: [
          // PDF export button
          _exportingPdf
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Exportar reporte PDF',
                  onPressed: _exportPdf,
                ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Integrantes'),
            Tab(icon: Icon(Icons.photo_library), text: 'Publicaciones'),
            Tab(icon: Icon(Icons.image), text: 'Fotos'),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildIntegrantesTab(fam),
              _buildPublicacionesTab(),
              _buildFotosTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Acciones de familia (desactivar, eliminar, editar) ─────────────────────

  Future<void> _handleDeactivate() async {
    final fam = _family!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Desactivar familia?'),
        content: Text(
          'La familia "${fam.familyName}" quedará inactiva pero sus datos se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _familiaApi.deactivateFamily(fam.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Familia desactivada.'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context, true); // Volver al listado
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handlePermanentDelete() async {
    final fam = _family!;
    // Doble confirmación para una acción irreversible
    final first = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar permanentemente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Eliminar la familia "${fam.familyName}" de forma permanente?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción no se puede deshacer. Se borrarán todos los miembros y registros relacionados.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    // Segunda confirmación
    final second = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirma la eliminación'),
        content: const Text('¿Seguro? Esta es una acción irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    try {
      await _familiaApi.permanentDeleteFamily(fam.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Familia eliminada permanentemente.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleEdit() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditFamilyPage(family: _family!)),
    );
    // Siempre recargamos: en la pantalla de edición, agregar o quitar
    // integrantes se guarda al instante, aunque el admin salga sin pulsar
    // "Guardar cambios". Sin esto, las secciones quedaban desactualizadas.
    if (mounted) {
      setState(() => _isLoading = true);
      await _fetchFamilyDetails(_family!.id!);
    }
  }

  Future<void> _handleManualCapacity() async {
    final fam = _family;
    if (fam?.id == null) return;
    final willClose = !fam!.cerradaManualmente;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          willClose ? '¿Marcar familia como llena?' : '¿Reabrir cupos?',
        ),
        content: Text(
          willClose
              ? 'La familia dejará de mostrarse con cupo aunque aún tenga lugares disponibles.'
              : 'La familia volverá a mostrarse con cupo si no ha alcanzado su límite de hijos EDI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willClose ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(willClose ? 'Marcar como llena' : 'Reabrir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isLoading = true);
      await _familiaApi.setFamilyManualFull(fam.id!, isFull: willClose);
      await _fetchFamilyDetails(fam.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willClose ? 'Familia marcada como llena.' : 'Cupos reabiertos.',
            ),
            backgroundColor: willClose ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Tab 1: Integrantes (original content) ──────────────────────────────────
  Widget _buildIntegrantesTab(Family fam) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(f: fam),
        const SizedBox(height: 16),

        // 1. Padres de familia
        _Section(
          title: 'Padres de familia',
          items: fam.parents,
          emptyText: 'Sin papá ni mamá asignados.',
          leadingIcon: Icons.volunteer_activism,
          accent: _primary,
          buildTrailing: (padre) => padre.tieneCuenta
              ? IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Ver perfil',
                  onPressed: () => Navigator.pushNamed(
                    context,
                    'student_detail',
                    arguments: padre.idUsuario,
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Chip(
                    label: Text(
                      'Pendiente',
                      style: TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
        ),
        const SizedBox(height: 12),

        // 2. Hijos sanguíneos (con cuenta en la app)
        _Section(
          title: 'Hijos sanguíneos',
          items: fam.householdChildren,
          emptyText: 'Sin hijos sanguíneos registrados.',
          leadingIcon: Icons.family_restroom,
          accent: Colors.teal,
          buildTrailing: (child) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Ver perfil',
                onPressed: () => Navigator.pushNamed(
                  context,
                  'student_detail',
                  arguments: child.idUsuario,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Quitar de la familia',
                onPressed: () => _handleDeleteMember(child),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Hijos del hogar (sin cuenta)
        _buildHogarChildrenSection(fam),
        const SizedBox(height: 12),

        // 4. Hijos EDI (alumnos asignados) — SIN tíos
        _Section(
          title: 'Hijos EDI',
          items: fam.assignedStudents,
          emptyText: 'Sin alumnos EDI asignados.',
          leadingIcon: Icons.school,
          accent: _gold,
          buildTrailing: (student) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Ver perfil',
                onPressed: () => Navigator.pushNamed(
                  context,
                  'student_detail',
                  arguments: student.idUsuario,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Quitar de la familia',
                onPressed: () => _handleDeleteMember(student),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 5. Tíos EDI — su propia sección, ya no dentro de "Hijos EDI"
        _Section(
          title: 'Tíos EDI',
          items: fam.uncles,
          emptyText: 'Sin tíos EDI asignados.',
          leadingIcon: Icons.handshake,
          accent: Colors.indigo,
          buildTrailing: (tio) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Ver perfil',
                onPressed: () => Navigator.pushNamed(
                  context,
                  'student_detail',
                  arguments: tio.idUsuario,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Quitar de la familia',
                onPressed: () => _handleDeleteMember(tio),
              ),
            ],
          ),
        ),

        // 6. Cualquier rol que la app no reconozca (no se oculta, se avisa)
        if (fam.otherMembers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Otros integrantes',
            items: fam.otherMembers,
            emptyText: '',
            leadingIcon: Icons.help_outline,
            accent: Colors.blueGrey,
            buildTrailing: (m) => IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Quitar de la familia',
              onPressed: () => _handleDeleteMember(m),
            ),
          ),
        ],

        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Agregar alumnos a esta familia'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () async {
            final bool? didAdd = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => _AddAlumnsSheet(family: fam),
            );
            if (didAdd == true && mounted) {
              setState(() => _isLoading = true);
              await _fetchFamilyDetails(fam.id!);
            }
          },
        ),

        // ── Admin actions ──────────────────────────────────────────────────
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),

        // Editar
        OutlinedButton.icon(
          icon: const Icon(Icons.edit, color: _primary),
          label: const Text(
            'Editar familia',
            style: TextStyle(color: _primary),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _handleEdit,
        ),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          icon: Icon(
            fam.cerradaManualmente ? Icons.lock_open : Icons.lock,
            color: fam.cerradaManualmente ? Colors.green : Colors.orange,
          ),
          label: Text(
            fam.cerradaManualmente
                ? 'Reabrir cupos manualmente'
                : 'Marcar familia como llena',
            style: TextStyle(
              color: fam.cerradaManualmente ? Colors.green : Colors.orange,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: fam.cerradaManualmente ? Colors.green : Colors.orange,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _handleManualCapacity,
        ),

        const SizedBox(height: 8),

        // Desactivar
        OutlinedButton.icon(
          icon: const Icon(Icons.visibility_off, color: Colors.orange),
          label: const Text(
            'Desactivar familia',
            style: TextStyle(color: Colors.orange),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.orange),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _handleDeactivate,
        ),

        const SizedBox(height: 8),

        // Eliminar permanentemente
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_forever, color: Colors.red),
          label: const Text(
            'Eliminar permanentemente',
            style: TextStyle(color: Colors.red),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _handlePermanentDelete,
        ),
      ],
    );
  }

  // ── Tab 2: Publicaciones ───────────────────────────────────────────────────
  Widget _buildPublicacionesTab() {
    if (_postsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No hay publicaciones de esta familia.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _posts.length,
      itemBuilder: (_, i) => _PostCard(post: _posts[i], absUrl: _absUrl),
    );
  }

  // ── Tab 3: Fotos (publicaciones con imagen) ────────────────────────────────
  Widget _buildFotosTab() {
    if (_postsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final fotos = _posts.where((p) {
      final img = (p['url_imagen'] ?? '').toString();
      return img.isNotEmpty && img != 'null';
    }).toList();

    if (fotos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No hay fotos publicadas.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: fotos.length,
      itemBuilder: (_, i) {
        final post = fotos[i];
        final imgUrl = _absUrl((post['url_imagen'] ?? '').toString());
        final autor = '${post['nombre'] ?? ''} ${post['apellido'] ?? ''}'
            .trim();
        final fecha = _formatDate(post['created_at']);
        return GestureDetector(
          onTap: () => _showImageDetail(
            context,
            imgUrl,
            autor,
            fecha,
            (post['mensaje'] ?? '').toString(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      autor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString()).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  void _showImageDetail(
    BuildContext context,
    String url,
    String autor,
    String fecha,
    String mensaje,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white, size: 60),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (autor.isNotEmpty)
                    Text(
                      autor,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (fecha.isNotEmpty)
                    Text(
                      fecha,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  if (mensaje.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      mensaje,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets (unchanged from original) ─────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.f});
  final Family f;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.familyName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Padre: ${f.fatherName ?? "No asignado"}'),
            Text('Madre: ${f.motherName ?? "No asignada"}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.home, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Residencia: ${f.residence}',
                  style: TextStyle(
                    color: f.residence == 'Interna' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (f.descripcion != null && f.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                f.descripcion!,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.emptyText,
    required this.buildTrailing,
    required this.leadingIcon,
    this.accent = Colors.grey,
  });
  final String title;
  final List<FamilyMember> items;
  final String emptyText;
  final Widget Function(FamilyMember) buildTrailing;
  final IconData leadingIcon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(leadingIcon, size: 18, color: accent),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // Contador por sección, para saber de un vistazo cuántos hay.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                emptyText,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          else
            ...items.map(
              (e) => ListTile(
                dense: true,
                leading: Icon(leadingIcon, color: accent),
                title: Text(e.fullName),
                // La etiqueta sale del propio tipo de miembro, así que un tío
                // nunca puede aparecer rotulado como hijo.
                subtitle: Text(
                  e.pendiente
                      ? '${e.roleLabel} · sin cuenta vinculada'
                      : e.roleLabel,
                ),
                trailing: buildTrailing(e),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Post card widget ───────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.absUrl});
  final dynamic post;
  final String Function(String?) absUrl;

  @override
  Widget build(BuildContext context) {
    final autor = '${post['nombre'] ?? ''} ${post['apellido'] ?? ''}'.trim();
    final mensaje = (post['mensaje'] ?? '').toString();
    final imgUrl = absUrl((post['url_imagen'] ?? '').toString());
    final hasImg = imgUrl.isNotEmpty;
    final fecha = _fmt(post['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImg)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                imgUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: Color.fromRGBO(19, 67, 107, 1),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        autor.isEmpty ? 'Desconocido' : autor,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      fecha,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                if (mensaje.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(mensaje, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString()).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }
}

// ── Add alumns sheet (unchanged) ───────────────────────────────────────────────
class _AddAlumnsSheet extends StatefulWidget {
  final Family family;
  const _AddAlumnsSheet({required this.family});
  @override
  State<_AddAlumnsSheet> createState() => _AddAlumnsSheetState();
}

class _AddAlumnsSheetState extends State<_AddAlumnsSheet> {
  final _controller = AddAlumnsController();
  final _alumnSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.init(context);
    _controller.selectFamily(widget.family);
  }

  @override
  void dispose() {
    _controller.dispose();
    _alumnSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asignar alumnos a:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            widget.family.familyName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color.fromRGBO(19, 67, 107, 1),
            ),
          ),
          const SizedBox(height: 20),
          _buildAlumnSelector(),
          const SizedBox(height: 20),
          _buildSelectedAlumnsList(),
          const SizedBox(height: 30),
          _buildSaveButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAlumnSelector() {
    return Column(
      children: [
        TextField(
          controller: _alumnSearchCtrl,
          decoration: InputDecoration(
            labelText: 'Buscar alumno por matrícula o nombre',
            prefixIcon: const Icon(Icons.person_search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: _controller.searchAlumns,
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<UserMini>>(
          valueListenable: _controller.alumnSearchResults,
          builder: (context, results, _) {
            if (results.isEmpty) return const SizedBox.shrink();
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: Card(
                elevation: 2,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final a = results[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.school)),
                      title: Text('${a.nombre} ${a.apellido}'),
                      subtitle: Text('Matrícula: ${a.matricula ?? 'N/A'}'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.green,
                        ),
                        onPressed: () {
                          _controller.addAlumn(a);
                          _alumnSearchCtrl.clear();
                          _controller.searchAlumns('');
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSelectedAlumnsList() {
    return ValueListenableBuilder<List<UserMini>>(
      valueListenable: _controller.selectedAlumns,
      builder: (_, alumns, __) {
        if (alumns.isEmpty) {
          return const Center(
            child: Text(
              'Ningún alumno añadido todavía.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return SizedBox(
          height: 100,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: alumns
                  .map(
                    (a) => Chip(
                      label: Text('${a.nombre} ${a.apellido}'),
                      avatar: const Icon(Icons.school),
                      onDeleted: () => _controller.removeAlumn(a),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (_, loading, __) => ElevatedButton.icon(
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(loading ? 'GUARDANDO...' : 'GUARDAR ASIGNACIONES'),
          onPressed: loading ? null : _controller.saveAssignments,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
