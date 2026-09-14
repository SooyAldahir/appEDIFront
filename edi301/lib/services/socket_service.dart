import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:edi301/core/api_client_http.dart';

/// Conexión de tiempo real con el backend.
///
/// El servidor exige autenticación: se manda el mismo `session_token` que usa
/// la API REST en el handshake. Sin token no se intenta conectar, y después
/// de iniciar o cerrar sesión hay que llamar a [reconnectWithAuth] para que
/// el socket vuelva a levantarse con las credenciales correctas.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  Completer<void>? _connectedCompleter;

  /// Salas activas con su número de referencias: una misma sala puede ser
  /// usada por varias pantallas a la vez (chat familiar y galería, por
  /// ejemplo) y solo se abandona cuando la última se va.
  final Map<String, int> _roomReferences = <String, int>{};

  /// Listeners registrados por las pantallas. Se guardan aquí para poder
  /// volver a engancharlos cuando el socket se crea o se rehace (por ejemplo
  /// tras iniciar sesión), y para que cada pantalla quite el suyo sin borrar
  /// los de las demás.
  final Map<String, Set<void Function(dynamic)>> _listeners =
      <String, Set<void Function(dynamic)>>{};

  String? _token;
  bool _unauthorized = false;

  IO.Socket get socket {
    if (_socket == null) {
      throw StateError('Socket no inicializado. Llama initSocket() primero.');
    }
    return _socket!;
  }

  bool get isReady => _socket != null;
  bool get isConnected => _socket?.connected == true;

  /// `true` si el servidor rechazó el token. La UI puede usarlo para saber
  /// que hace falta volver a iniciar sesión.
  bool get isUnauthorized => _unauthorized;

  Future<String?> _readToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token');
      return (token != null && token.isNotEmpty) ? token : null;
    } catch (_) {
      return null;
    }
  }

  /// Crea la conexión si hay sesión guardada. Es seguro llamarla varias veces.
  Future<void> initSocket() async {
    if (_socket != null) return;

    final token = await _readToken();
    if (token == null) {
      // Todavía no hay sesión (primer arranque o después de logout). No se
      // intenta conectar: el servidor rechazaría el handshake.
      print('🌐 Socket: sin sesión, no se conecta todavía.');
      return;
    }

    _token = token;
    _unauthorized = false;

    final url = ApiHttp.baseUrl;
    print('🌐 Socket init -> $url');

    _connectedCompleter = Completer<void>();

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setPath('/socket.io')
          // websocket primero y polling de respaldo: con polling puro cada
          // evento cuesta una petición HTTP y, detrás de un proxy con varias
          // réplicas, falla de forma intermitente.
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(5000)
          .setTimeout(8000)
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _unauthorized = false;
      print('✅ Socket conectado (id=${_socket!.id})');
      // Al reconectar hay que volver a pedir todas las salas: el servidor no
      // recuerda al socket anterior.
      for (final roomId in _roomReferences.keys) {
        _socket!.emit('join_room', roomId);
      }
      if (_connectedCompleter != null && !_connectedCompleter!.isCompleted) {
        _connectedCompleter!.complete();
      }
    });

    _socket!.onDisconnect((reason) {
      print('⚠️ Socket desconectado ($reason)');
      // Completer nuevo para los próximos ensureConnected().
      _connectedCompleter = Completer<void>();
    });

    _socket!.onConnectError((e) {
      final detail = e?.toString() ?? '';
      if (detail.contains('unauthorized')) {
        // Token inválido o sesión cerrada: reintentar no sirve de nada y
        // además satura el servidor.
        _unauthorized = true;
        print('❌ Socket: token rechazado. Se detienen los reintentos.');
        _socket?.disconnect();
      } else {
        print('❌ Socket connect_error: $detail');
      }
    });

    _socket!.onError((e) => print('❌ Socket error: $e'));

    _socket!.on('room_error', (data) => print('❌ room_error: $data'));

    // Reengancha lo que las pantallas ya habían pedido escuchar.
    _attachListeners();

    _socket!.connect();
  }

  // ── Listeners ──────────────────────────────────────────────────────────────

  /// Registra un listener de forma segura, aunque el socket todavía no exista.
  ///
  /// Usar esto en vez de `socketService.socket.on(...)`: como la conexión se
  /// crea de forma asíncrona (hay que leer el token antes), acceder a `socket`
  /// directamente puede lanzar StateError si la pantalla se adelanta.
  void on(String event, void Function(dynamic) handler) {
    _listeners.putIfAbsent(event, () => <void Function(dynamic)>{}).add(handler);
    _socket?.on(event, handler);
    unawaited(ensureConnected());
  }

  /// Quita un listener concreto. Sin `handler` quita todos los de ese evento
  /// (evítalo: borraría también los de otras pantallas).
  void off(String event, [void Function(dynamic)? handler]) {
    if (handler == null) {
      _listeners.remove(event);
      _socket?.off(event);
      return;
    }
    final handlers = _listeners[event];
    handlers?.remove(handler);
    if (handlers != null && handlers.isEmpty) _listeners.remove(event);
    _socket?.off(event, handler);
  }

  void _attachListeners() {
    final socket = _socket;
    if (socket == null) return;
    _listeners.forEach((event, handlers) {
      for (final handler in handlers) {
        socket.on(event, handler);
      }
    });
  }

  /// Rehace la conexión con el token actual. Llamar después de iniciar sesión
  /// (token nuevo) y después de cerrarla (para que deje de estar conectado).
  Future<void> reconnectWithAuth() async {
    final token = await _readToken();
    if (token == _token && isConnected) return;

    _teardown();
    await initSocket();
  }

  Future<void> ensureConnected({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await initSocket();

    if (isConnected) return;
    if (_socket == null || _unauthorized) return;

    try {
      await (_connectedCompleter?.future ?? Future.value()).timeout(timeout);
    } catch (_) {
      print('⚠️ ensureConnected timeout. connected=$isConnected');
    }
  }

  Future<void> joinFamilyRoom(int familyId) => _joinRoom('familia_$familyId');

  Future<void> joinChatRoom(int salaId) => _joinRoom('sala_$salaId');

  Future<void> joinInstitucionalRoom() => _joinRoom('institucional');

  Future<void> joinUserRoom(int userId) => _joinRoom('user_$userId');

  Future<void> _joinRoom(String roomId) async {
    final previousReferences = _roomReferences[roomId] ?? 0;
    _roomReferences[roomId] = previousReferences + 1;

    await ensureConnected();

    if (!isConnected) {
      print('⚠️ No conectado; la sala $roomId se pedirá al reconectar');
      return;
    }

    // Solo la primera pantalla que pide la sala emite el join. Antes se
    // comparaba además contra el estado previo de la conexión, y por eso una
    // sala pedida mientras el socket aún conectaba se quedaba sin unir.
    if (previousReferences == 0) {
      _socket!.emit('join_room', roomId);
      print('➡️ join_room $roomId');
    }
  }

  void leaveRoom(String roomId) {
    final references = _roomReferences[roomId] ?? 0;

    // La sala nunca se pidió: salir de ella dejaría el contador en negativo y
    // sacaría de la sala a la pantalla que sí la está usando.
    if (references == 0) return;

    if (references > 1) {
      _roomReferences[roomId] = references - 1;
      return;
    }

    _roomReferences.remove(roomId);

    if (_socket == null || !isConnected) return;

    _socket!.emit('leave_room', roomId);
    print('⬅️ leave_room $roomId');
  }

  void _teardown() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedCompleter = null;
    _token = null;
    _unauthorized = false;
    // Las salas NO se limpian: si esto fue una reconexión, se vuelven a pedir
    // en cuanto el socket nuevo se conecte.
  }

  /// Corta la conexión y olvida salas y listeners. Usar al cerrar sesión.
  void disconnect() {
    _teardown();
    _roomReferences.clear();
    _listeners.clear();
    print('🧹 Socket disposed');
  }
}
