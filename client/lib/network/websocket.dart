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

  final data = jsonDecode(message as String);
  if (data is! Map<String, dynamic>) {
    print('Unexpected message format.');
    return;
  }

  final type = data['type'];
  print("Message type: $type");

  switch (type) {
    case 'welcome':
      print("✅ Welcome message: $data");

      final id = data['playerId'];
      if (id is String) {
        playerId = id;
        print("🎯 Assigned playerId: $playerId");
      } else {
        print('❌ Error: playerId is not a string. Received: $id');
        onError?.call("invalid_player_id");
        return;
      }

      if (data['players'] is List) {
        final players = (data['players'] as List)
            .map((p) => Player.fromJson(p))
            .toList();
        print("👥 Players from welcome: ${players.map((p) => p.username)}");
        onStateUpdate?.call(players);
      }
      break;

    case 'playerList':
      if (data['players'] is List) {
        final players = (data['players'] as List)
            .map((p) => Player.fromJson(p))
            .toList();

        if (playerId == null) {
          print('⚠️ playerId not yet assigned! Ignoring early playerList.');
          return;
        }

        print("📃 PlayerList update received. Current playerId: $playerId");
        onPlayerListUpdate?.call(players);
      }
      break;

    case 'eliminated':
      final eliminatedId = data['playerId'];
      print("💀 Eliminated message: $eliminatedId vs current: $playerId");

      if (eliminatedId != null &&
          playerId != null &&
          eliminatedId == playerId) {
        onEliminated?.call(playerId!);
      }
      break;

    case 'error':
      final msg = data['message'] ?? 'unknown_error';
      print('❌ Server error: $msg');
      onError?.call(msg);
      break;

    default:
      print("❓ Unhandled message type: $type");
      break;
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
    } else {
      print("WebSocket channel is not connected.");
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
