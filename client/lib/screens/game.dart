import '../models/ball.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/hud.dart';
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
  // Instead of a field, _myPlayerId is now a getter that reads from the WebSocketService
  String? get _myPlayerId => widget.webSocketService.playerId;
  final GlobalKey _arenaKey = GlobalKey();

  List<Ball> _balls = [];
  List<Player> _players = [];
  double _arenaLogicalSize = 1000.0;

  // Convert global pointer position to logical arena coordinates
  Offset _getLogicalFromGlobal(Offset globalPosition) {
    final RenderBox? box = _arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    final Offset local = box.globalToLocal(globalPosition);
    final double scale = box.size.width / _arenaLogicalSize;
    return Offset(local.dx / scale, local.dy / scale);
  }

  void _startSendingMovement(Offset logicalTarget) {
    _lastPointerLogical = logicalTarget;
    // Wait until _myPlayerId is set before starting movement
    if (_myPlayerId == null) {
      print('No playerId yet, delaying movement start.');
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
      // If user is holding/tapping, try to send movement again when balls update
      if (_lastPointerLogical != null && _myPlayerId != null) {
        _sendMovementTo(_lastPointerLogical!);
      }
    };
    widget.webSocketService.onWelcome = (playerId) {
      // If user is holding/tapping, start movement now that playerId is available
      if (_lastPointerLogical != null) {
        _startSendingMovement(_lastPointerLogical!);
      }
    };
    widget.webSocketService.requestPlayerList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.webSocketService.onArenaInfo = (double size) {
      if (size > 0 && size != _arenaLogicalSize) {
        setState(() {
          _arenaLogicalSize = size;
        });
      }
    };
  }

  // In build(), input is now only enabled if _myPlayerId is set
  @override
  Widget build(BuildContext context) {
    final double margin = 8.0;
    final double availableHeight = MediaQuery.of(context).size.height - margin * 2;
    final double availableWidth = MediaQuery.of(context).size.width - margin * 2;
    final double scale = (availableHeight < availableWidth)
        ? availableHeight / _arenaLogicalSize
        : availableWidth / _arenaLogicalSize;
    final double displaySize = _arenaLogicalSize * scale;
    final bool ready = _myPlayerId != null;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 148, 148, 148),
      body: Stack(
        children: [
          Center(
            child: Container(
              key: _arenaKey,
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
          if (!ready)
            // Show a loading overlay until playerId is set
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (ready)
            GestureDetector(
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
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
        ],
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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );

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