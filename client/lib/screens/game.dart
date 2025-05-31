import '../models/ball.dart';
import 'dart:math' as math;
import 'dart:async';
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
  Timer? _moveTimer;
  Offset? _lastPointerLogical;
  String? _myPlayerId;

  final GlobalKey _arenaKey = GlobalKey(); // Add this line

  // Helper: Convert global pointer position to logical arena coordinates
  Offset _getLogicalFromGlobal(Offset globalPosition) {
    final RenderBox? box = _arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    final Offset local = box.globalToLocal(globalPosition);
    final double scale = box.size.width / _arenaLogicalSize;
    return Offset(local.dx / scale, local.dy / scale);
  }

  void _startSendingMovement(Offset logicalTarget) {
    _lastPointerLogical = logicalTarget;
    // Only start movement if my ball exists
    if (_myPlayerId == null || !_balls.any((b) => b.id == _myPlayerId)) {
      print('Ball not ready yet, ignoring movement.');
      return;
    }
    _moveTimer?.cancel();
    _moveTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _sendMovementTo(_lastPointerLogical!);
    });
    _sendMovementTo(logicalTarget); // Send immediately
  }

  void _updateSendingMovement(Offset logicalTarget) {
    _lastPointerLogical = logicalTarget;
  }

  void _stopSendingMovement() {
    _moveTimer?.cancel();
    _moveTimer = null;
    _lastPointerLogical = null;
    widget.webSocketService.sendMovement(0, 0);
  }

  void _sendMovementTo(Offset logicalTarget) {
    if (_myPlayerId == null) {
      print('No playerId yet.');
      return;
    }
    Ball? myBall;
    try {
      myBall = _balls.firstWhere((b) => b.id == _myPlayerId);
    } catch (_) {
      print('My ball not found in _balls.');
      return;
    }
    if (myBall == null) {
      print('My ball is null.');
      return;
    }

    print('My ball position: (${myBall.x}, ${myBall.y}), Target: (${logicalTarget.dx}, ${logicalTarget.dy})');

    final double dx = logicalTarget.dx - myBall.x;
    final double dy = logicalTarget.dy - myBall.y;
    final double length = math.sqrt(dx * dx + dy * dy);
    final double dirX = length > 0 ? dx / length : 0;
    final double dirY = length > 0 ? dy / length : 0;
    print('Sending direction: ($dirX, $dirY)');
    widget.webSocketService.sendMovement(dirX, dirY);
  }

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
    // Listen for welcome message to get playerId
    widget.webSocketService.onWelcome = (playerId) {
      setState(() {
        _myPlayerId = playerId;
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
        onPanStart: (DragStartDetails details) {
          final logicalTarget = _getLogicalFromGlobal(details.globalPosition);
          _startSendingMovement(logicalTarget);
        },
        onPanUpdate: (DragUpdateDetails details) {
          final logicalTarget = _getLogicalFromGlobal(details.globalPosition);
          _updateSendingMovement(logicalTarget);
        },
        onPanEnd: (DragEndDetails details) {
          _stopSendingMovement();
        },
        onPanCancel: () {
          _stopSendingMovement();
        },
        onTapDown: (TapDownDetails details) {
          final logicalTarget = _getLogicalFromGlobal(details.globalPosition);
          _startSendingMovement(logicalTarget);
        },
        onTapUp: (TapUpDetails details) {
          _stopSendingMovement();
        },
        child: Stack(
          children: [
            Center(
              child: Container(
                key: _arenaKey, // Attach the key here
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

  @override
  void dispose() {
    _moveTimer?.cancel();
    super.dispose();
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