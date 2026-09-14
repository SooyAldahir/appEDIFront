import 'package:flutter/material.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/services/fotos_api.dart';
import 'package:edi301/services/socket_service.dart';

class FamilyGallery extends StatefulWidget {
  final int idFamilia;

  const FamilyGallery({Key? key, required this.idFamilia}) : super(key: key);

  @override
  State<FamilyGallery> createState() => _FamilyGalleryState();
}

class _FamilyGalleryState extends State<FamilyGallery> {
  final SocketService _socketService = SocketService();
  final FotosApi _api = FotosApi();
  List<dynamic> _fotos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarFotos();
    _escucharFotosNuevas();
  }

  /// Antes este widget solo hacía `leaveRoom` en dispose SIN haber entrado
  /// nunca a la sala: eso descontaba una referencia ajena y sacaba de
  /// `familia_X` al chat familiar, que dejaba de recibir mensajes en vivo.
  /// Ahora entra de verdad y además escucha el evento, que el backend ya
  /// emitía desde fotos.controller.
  Future<void> _escucharFotosNuevas() async {
    await _socketService.joinFamilyRoom(widget.idFamilia);
    if (!mounted) return;
    _socketService.on('foto_agregada', _onFotoAgregada);
  }

  void _onFotoAgregada(dynamic _) {
    if (mounted) _cargarFotos();
  }

  Future<void> _cargarFotos() async {
    final data = await _api.getFotosFamilia(widget.idFamilia);
    if (mounted) {
      setState(() {
        _fotos = data;
        _loading = false;
      });
    }
  }

  String _getFullUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http')) return rawUrl;
    final normalized = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return '${ApiHttp.baseUrl}$normalized';
  }

  void _abrirVisor(int indexInicial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenViewer(
          fotos: _fotos,
          initialIndex: indexInicial,
          baseUrl: ApiHttp.baseUrl,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Se quita SOLO este handler, no todos los del evento.
    _socketService.off('foto_agregada', _onFotoAgregada);
    _socketService.leaveRoom('familia_${widget.idFamilia}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_fotos.isEmpty) {
      return Container(
        height: 0,
        width: double.infinity,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 10),
            const Text(
              "Aún no hay fotos en la familia",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: _fotos.length,
      itemBuilder: (context, index) {
        final item = _fotos[index];
        final url = _getFullUrl(item['url_imagen'] ?? '');

        return GestureDetector(
          onTap: () => _abrirVisor(index),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}

class _FullScreenViewer extends StatefulWidget {
  final List<dynamic> fotos;
  final int initialIndex;
  final String baseUrl;

  const _FullScreenViewer({
    required this.fotos,
    required this.initialIndex,
    required this.baseUrl,
  });

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${_currentIndex + 1} / ${widget.fotos.length}",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.fotos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final item = widget.fotos[index];
          String url = item['url_imagen'];
          if (!url.startsWith('http')) url = '${widget.baseUrl}$url';

          return Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
