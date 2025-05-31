import 'package:bump_zone/models/ball.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:bump_zone/models/player.dart';
import 'dart:typed_data';

typedef ArenaInfoCallback = void Function(double size);


class WebSocketService {
  Function(List<Ball>)? onBallsUpdate;
  WebSocketChannel? _channel;
  final String url;
  Function(List<Player>)? onPlayerListUpdate;
  Function(String)? onError;
  ArenaInfoCallback? onArenaInfo;
  void Function(String playerId)? onWelcome;
  String? playerId; // <-- Add this

  WebSocketService(this.url);

  void sendMovement(double dx, double dy) {
    _send({'type': 'move', 'direction': {'dx': dx, 'dy': dy}});
  }

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          print('WebSocket error: $error');
          onError?.call('connection_failed');
        },
        onDone: () {
          print('WebSocket connection closed');
          onError?.call('connection_closed');
        },
      );
    } catch (e) {
      print('WebSocket connection failed: $e');
      onError?.call('connection_failed');
    }
  }

  void _onMessage(dynamic message) {
    // --- Handle binary balls update ---
    if (message is List<int>) {
      final bytes = Uint8List.fromList(message);
      final byteData = ByteData.sublistView(bytes);
      final count = byteData.getUint32(0, Endian.little);
      final balls = <Ball>[];
      for (int i = 0; i < count; i++) {
        final base = 4 + i * 16;
        final x = byteData.getFloat32(base + 0, Endian.little);
        final y = byteData.getFloat32(base + 4, Endian.little);
        final vx = byteData.getFloat32(base + 8, Endian.little);
        final vy = byteData.getFloat32(base + 12, Endian.little);
        // NOTE: id is not sent, so use a placeholder or match by order
        balls.add(Ball(id: '$i', x: x, y: y, vx: vx, vy: vy));
      }
      if (onBallsUpdate != null) {
        onBallsUpdate!(balls);
      }
      return;
    }

    print("WebSocket message received: $message");

    final data = jsonDecode(message as String);
    if (data is! Map<String, dynamic>) {
      print('Unexpected message format.');
      return;
    }

    final type = data['type'];
    if (type == 'balls' && data['balls'] is List) {
      final balls = (data['balls'] as List)
          .map((b) => Ball.fromJson(b))
          .toList();
      if (onBallsUpdate != null) {
        onBallsUpdate!(balls);
      }
      return;
    }
    if (type == 'arenaInfo' && data['size'] != null) {
      final size = (data['size'] as num).toDouble();
      if (onArenaInfo != null) {
        onArenaInfo!(size);
      }
      return;
    }
    // Call the onWelcome callback when a welcome message is received
    if (type == 'welcome' && data['playerId'] != null) {
      print('Welcome message received with playerId: ${data['playerId']}');
      playerId = data['playerId'] as String; // <-- Store playerId
      if (onWelcome != null) onWelcome!(playerId!);
    }

    switch (type) {
      case 'playerList':
        if (data['players'] is List) {
          final players = (data['players'] as List)
              .map((p) => Player.fromJson(p))
              .toList();
          onPlayerListUpdate?.call(players);
        }
        break;

      case 'error':
        final msg = data['message'] ?? 'unknown_error';
        print('Server error: $msg');
        onError?.call(msg);
        break;

      default:
        print("Unhandled message type: $type");
        break;
    }
  }

  void join(String username) {
    _send({'type': 'join', 'username': username});
  }

  void leave() {
    _send({'type': 'leave'});
  }

  void requestPlayerList() {
    _send({'type': 'getPlayers'});
  }

  void _send(Map<String, dynamic> message) {
    final encoded = jsonEncode(message);
    print("🔹 Sending WebSocket message: $encoded"); // ✅ Debug output

    if (_channel != null) {
      _channel!.sink.add(encoded);
    } else {
      print("❌ WebSocket channel is not connected.");
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
