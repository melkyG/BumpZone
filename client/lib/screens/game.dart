import '../models/ball.dart';
import 'dart:math' as math;
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
  List<Ball> _balls = [];
  List<Player> _players = [];
  @override
  void initState() {
    super.initState();
    widget.webSocketService.onPlayerListUpdate = (players) {
      setState(() {
        _players = players;
      });
    };
    widget.webSocketService.onBallsUpdate = (balls) {
      setState(() {
        _balls = balls;
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
      backgroundColor: const Color.fromARGB(255, 148, 148, 148),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (TapDownDetails details) {
          // Get the global click position
          final RenderBox stackBox = context.findRenderObject() as RenderBox;
          final Offset globalOffset = stackBox.globalToLocal(details.globalPosition);
          // Calculate the offset of the arena inside the window
          final double margin = 8.0;
          final double availableHeight = MediaQuery.of(context).size.height - margin * 2;
          final double availableWidth = MediaQuery.of(context).size.width - margin * 2;
          final double scale = (availableHeight < availableWidth)
              ? availableHeight / _arenaLogicalSize
              : availableWidth / _arenaLogicalSize;
          final double displaySize = _arenaLogicalSize * scale;
          final double arenaLeft = (MediaQuery.of(context).size.width - displaySize) / 2;
          final double arenaTop = (MediaQuery.of(context).size.height - displaySize) / 2;
          // Convert the click to logical coordinates (can be outside arena)
          final double logicalX = (globalOffset.dx - arenaLeft) / scale;
          final double logicalY = (globalOffset.dy - arenaTop) / scale;
          if (_balls.isNotEmpty) {
            // For now, assume the first ball is the local player
            final Ball myBall = _balls[0];
            final double dx = logicalX - myBall.x;
            final double dy = logicalY - myBall.y;
            final double length = math.sqrt(dx * dx + dy * dy);
            final double dirX = length > 0 ? dx / length : 0;
            final double dirY = length > 0 ? dy / length : 0;
            debugPrint('Clicked at logical: ($logicalX, $logicalY), direction: ($dirX, $dirY)');
            widget.webSocketService.sendMovement(dirX, dirY);
          }
        },
        child: Stack(
          children: [
            Center(
              child: Container(
                width: displaySize,
                height: displaySize,
                color: Colors.white,
                child: CustomPaint(
                  size: Size(_arenaLogicalSize, _arenaLogicalSize),
                  painter: _ArenaPainter(balls: _balls, arenaLogicalSize: _arenaLogicalSize),
                  isComplex: false,
                  willChange: false,
                ),
              ),
            ),
            PlayerListHUD(players: _players),
          ],
        ),
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  final List<Ball> balls;
  final double arenaLogicalSize;
  _ArenaPainter({required this.balls, required this.arenaLogicalSize});

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

    // Draw all balls, scaling logical coordinates to display coordinates
    final Paint ballPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    const double logicalRadius = 18;
    final double scale = size.width / arenaLogicalSize;
    for (final ball in balls) {
      canvas.drawCircle(
        Offset(ball.x * scale, ball.y * scale),
        logicalRadius * scale,
        ballPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}