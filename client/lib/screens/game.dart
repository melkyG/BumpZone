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

  // Arena size, defaults to 1000.0 but will update if server provides a value
  double _arenaLogicalSize = 1000.0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for arenaInfo messages from the server
    widget.webSocketService.onArenaInfo = (double size) {
      if (size > 0 && size != _arenaLogicalSize) {
        setState(() {
          _arenaLogicalSize = size;
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    // Get the available size for the arena (fit to height, with margin)
    final double margin = 8.0;
    final double availableHeight = MediaQuery.of(context).size.height - margin * 2;
    final double availableWidth = MediaQuery.of(context).size.width - margin * 2;
    final double scale = (availableHeight < availableWidth)
        ? availableHeight / _arenaLogicalSize
        : availableWidth / _arenaLogicalSize;
    final double displaySize = _arenaLogicalSize * scale;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Stack(
        children: [
          Center(
            child: SizedBox(
              width: displaySize,
              height: displaySize,
              child: CustomPaint(
                size: Size(_arenaLogicalSize, _arenaLogicalSize),
                painter: _ArenaPainter(),
                isComplex: false,
                willChange: false,
              ),
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
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    // Draw the outer square (arena)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}