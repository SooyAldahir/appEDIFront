// lib/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:edi301/core/api_client_http.dart'; // Para usar tu baseUrl

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late IO.Socket socket;

  void initSocket() {
    socket = IO.io(
      ApiHttp.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    socket.onConnect((_) => print('Conectado al servidor de Sockets'));
  }

  void joinFamilyRoom(int familyId) {
    socket.emit('join_room', familyId.toString());
  }
}
