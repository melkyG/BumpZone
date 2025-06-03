import 'package:bump_zone/models/ball.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:bump_zone/models/player.dart';
import 'dart:typed_data';
import 'dart:js_util' as js_util; // Add this for JS interop
import 'package:bump_zone/network/ball_binary.dart'; // <-- Add this
import 'package:bump_zone/network/arena_binary.dart'; // <-- Add this

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
  Function(ArenaState)? onArenaUpdate; // <-- Add this callback
  void Function(double spring, double damping, double mass, double restitution)? onBandSettingsUpdate;

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
    print('WebSocket raw message type: ${message.runtimeType}');

    // --- Handle binary arena update for Dart VM (List<int>) ---
    if (message is List<int>) {
      final arena = decodeArenaState(Uint8List.fromList(message));
      if (onArenaUpdate != null) {
        onArenaUpdate!(arena);
      }
      // Optionally: also call onBallsUpdate for legacy code
      if (onBallsUpdate != null) {
        onBallsUpdate!(arena.balls);
      }
      return;
    }

    // --- Handle binary arena update for Flutter web (ByteBuffer or JS-interop) ---
    if (message is! String && js_util.hasProperty(message, 'buffer')) {
      final buffer = js_util.getProperty(message, 'buffer');
      final arena = decodeArenaState(Uint8List.view(buffer));
      if (onArenaUpdate != null) {
        onArenaUpdate!(arena);
      }
      if (onBallsUpdate != null) {
        onBallsUpdate!(arena.balls);
      }
      return;
    }

    // Now it's safe to assume it's a String (JSON)
    print("WebSocket message received: $message");

    final data = jsonDecode(message as String);
    if (data is! Map) {
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
      case 'bandSettings':
        // Add debug print to see what is received
        print('[CLIENT] Received bandSettings: $data');
        if (onBandSettingsUpdate != null) {
          double parseNum(dynamic v, double fallback) {
            if (v is num) return v.toDouble();
            if (v is String) return double.tryParse(v) ?? fallback;
            return fallback;
          }
          onBandSettingsUpdate!(
            parseNum(data['springConstant'], 10.0),
            parseNum(data['dampingCoeff'], 1.0),
            parseNum(data['mass'], 1.0),
            parseNum(data['restitution'], 0.85),
          );
        }
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

  void sendBandSettings({
    required double springConstant,
    required double dampingCoeff,
    required double mass,
    required double restitution,
  }) {
    _send({
      'type': 'setBandSettings',
      'springConstant': springConstant,
      'dampingCoeff': dampingCoeff,
      'mass': mass,
      'restitution': restitution,
    });
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
