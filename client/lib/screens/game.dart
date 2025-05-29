import 'package:flutter/material.dart';
// import '../game/arena.dart';
// import '../game/ball.dart';
import '../models/player.dart';
import '../widgets/hud.dart';

// import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'package:bump_zone/network/websocket.dart';

class GameScreen extends StatefulWidget {
  final WebSocketService webSocketService;

  const GameScreen({super.key, required this.webSocketService});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Player> _players = [];
  @override
  void initState() {
    super.initState();
    widget.webSocketService.onPlayerListUpdate = (players) {
      setState(() {
        _players = players;
      });
    };
    
    // Request current player list when screen initializes
    widget.webSocketService.requestPlayerList();
  }

  @override
  Widget build(BuildContext context) {
    // Proportions for the arena
    final double arenaSize = MediaQuery.of(context).size.shortestSide * 0.8;
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: Size(arenaSize, arenaSize),
              painter: _ArenaPainter(),
            ),
          ),
          PlayerListHUD(players: _players),
        ],
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    // Draw the outer square (arena)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}