import 'package:flutter/material.dart';
import 'package:bump_zone/network/websocket.dart';

class GameScreen extends StatelessWidget {
  final WebSocketService webSocketService;

  const GameScreen({super.key, required this.webSocketService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Text('Game Screen (Placeholder)'),
      ),
    );
  }
}