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
    final data = jsonDecode(message as String) as Map<String, dynamic>;
    switch (data['type']) {
      case 'welcome':
        playerId = data['playerId'] as String;
        final players = (data['players'] as List)
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList();
        if (onStateUpdate != null) onStateUpdate!(players);
        if (onPlayerListUpdate != null) onPlayerListUpdate!(players);
        break;
      case 'state':
        final players = (data['players'] as List)
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList();
        if (onStateUpdate != null) onStateUpdate!(players);
        break;
      case 'playerList':
        final players = (data['players'] as List)
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList();
        if (onPlayerListUpdate != null) onPlayerListUpdate!(players);
        break;
      case 'eliminated':
        if (data['playerId'] == playerId && onEliminated != null) {
          onEliminated!(playerId!);
        }
        break;
      case 'error':
        if (onError != null) onError!(data['reason'] as String);
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
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}