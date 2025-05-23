import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:bump_zone/models/player.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final String url;
  Function(List<Player>)? onPlayerListUpdate;
  Function(List<Player>)? onStateUpdate;
  Function(String)? onEliminated;
  Function(String)? onError;
  String? playerId;

  WebSocketService(this.url);

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          print('WebSocket error: $error');
          if (onError != null) onError!('connection_failed');
        },
        onDone: () {
          print('WebSocket connection closed');
          if (onError != null) onError!('connection_closed');
        },
      );
    } catch (e) {
      print('WebSocket connection failed: $e');
      if (onError != null) onError!('connection_failed');
    }
  }

  void _onMessage(dynamic message) {
    print("WebSocket message received: $message");

    final data = jsonDecode(message as String) as Map<String, dynamic>;
    final type = data['type'];
    print("Message type: $type");

    switch (type) {
      case 'welcome':
        print("Welcome message: $data");
        // existing code...
        break;
      case 'eliminated':
        final eliminatedId = data['playerId'];
        if (eliminatedId != null && eliminatedId == playerId && onEliminated != null) {
          onEliminated!(playerId!);
        }
        break;

      // rest unchanged
    }
  }

  void join(String username) {
    _send({'type': 'join', 'username': username});
  }

  void sendMovement(double dx, double dy) {
    _send({'type': 'move', 'direction': {'dx': dx, 'dy': dy}});
  }

  void leave() {
    _send({'type': 'leave'});
  }

  void _send(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}