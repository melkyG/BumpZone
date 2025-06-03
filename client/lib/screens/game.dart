import '../models/ball.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/hud.dart';
import 'package:bump_zone/network/websocket.dart';
import 'package:bump_zone/network/arena_binary.dart'; // <-- Add this

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
  List<Band> _bands = [];
  List<BandSegment> _posts = [];
  double _arenaLogicalSize = 1000.0;

  // Band settings state (add these fields)
  double _springConstant = 10.0;
  double _dampingCoeff = 1.0;
  double _mass = 1.0;
  double _restitution = 0.85;

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
      myBall = null;
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
    widget.webSocketService.onArenaUpdate = (arena) {
      print('[DEBUG] Arena bands received: ${arena.bands.length}');
      if (arena.bands.isNotEmpty) {
        print('[DEBUG] First band segment count: ${arena.bands[0].segments.length}');
      }
      setState(() {
        _balls = arena.balls;
        _bands = arena.bands;
        _posts = arena.posts;
      });
      // If user is holding/tapping, try to send movement again when balls update
      if (_lastPointerLogical != null && _myPlayerId != null) {
        _sendMovementTo(_lastPointerLogical!);
      }
    };
    widget.webSocketService.onBallsUpdate = (balls) {
      setState(() {
        _balls = balls;
      });
    };
    widget.webSocketService.onWelcome = (playerId) {
      // If user is holding/tapping, start movement now that playerId is available
      if (_lastPointerLogical != null) {
        _startSendingMovement(_lastPointerLogical!);
      }
    };
    widget.webSocketService.onBandSettingsUpdate = (spring, damping, mass, restitution) {
      setState(() {
        _springConstant = spring;
        _dampingCoeff = damping;
        _mass = mass;
        _restitution = restitution;
      });
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

    // Find my ball
    Ball? myBall;
    try {
      myBall = _balls.firstWhere((b) => b.id == _myPlayerId);
    } catch (_) {
      myBall = null;
    }
    Offset cameraOffset = (myBall != null)
        ? Offset(myBall.x, myBall.y)
        : Offset(_arenaLogicalSize / 2, _arenaLogicalSize / 2);

    return Scaffold(
      body: Stack(
        children: [
          // Allow clicking anywhere (including outside arena)
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
              child: Center(
                child: Container(
                  key: _arenaKey,
                  width: displaySize,
                  height: displaySize,
                  color: Colors.white,
                  child: CustomPaint(
                    size: Size(_arenaLogicalSize, _arenaLogicalSize),
                    painter: _ArenaPainter(
                      balls: _balls,
                      bands: _bands,
                      posts: _posts,
                      arenaLogicalSize: _arenaLogicalSize,
                      cameraOffset: cameraOffset, // pass camera offset
                    ),
                    isComplex: false,
                    willChange: false,
                  ),
                ),
              ),
            ),
          ),
          PlayerListHUD(players: _players),
          HUD(
            players: _players,
            springConstant: _springConstant,
            dampingCoeff: _dampingCoeff,
            mass: _mass,
            restitution: _restitution,
            onSpringChanged: (v) {
              setState(() => _springConstant = v);
              widget.webSocketService.sendBandSettings(
                springConstant: v,
                dampingCoeff: _dampingCoeff,
                mass: _mass,
                restitution: _restitution,
              );
            },
            onDampingChanged: (v) {
              setState(() => _dampingCoeff = v);
              widget.webSocketService.sendBandSettings(
                springConstant: _springConstant,
                dampingCoeff: v,
                mass: _mass,
                restitution: _restitution,
              );
            },
            onMassChanged: (v) {
              setState(() => _mass = v);
              widget.webSocketService.sendBandSettings(
                springConstant: _springConstant,
                dampingCoeff: _dampingCoeff,
                mass: v,
                restitution: _restitution,
              );
            },
            onRestitutionChanged: (v) {
              setState(() => _restitution = v);
              widget.webSocketService.sendBandSettings(
                springConstant: _springConstant,
                dampingCoeff: _dampingCoeff,
                mass: _mass,
                restitution: v,
              );
            },
          ),
          if (!ready)
            // Show a loading overlay until playerId is set
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
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
  final List<Band> bands;
  final List<BandSegment> posts;
  final double arenaLogicalSize;
  final Offset cameraOffset;

  _ArenaPainter({
    required this.balls,
    required this.bands,
    required this.posts,
    required this.arenaLogicalSize,
    required this.cameraOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / arenaLogicalSize;
    // Defensive: cameraOffset may be null or NaN
    final double camX = (cameraOffset.dx.isNaN || cameraOffset.dx.isInfinite)
        ? arenaLogicalSize / 2
        : cameraOffset.dx;
    final double camY = (cameraOffset.dy.isNaN || cameraOffset.dy.isInfinite)
        ? arenaLogicalSize / 2
        : cameraOffset.dy;
    canvas.translate(
      size.width / 2 - camX * scale,
      size.height / 2 - camY * scale,
    );

    // Draw arena border
    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, arenaLogicalSize * scale, arenaLogicalSize * scale),
      borderPaint,
    );

    // Draw bands
    final Paint bandPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    for (final band in bands) {
      if (band.segments.isNotEmpty) {
        final first = band.segments[0];
        final path = Path();
        path.moveTo(first.x * scale, first.y * scale);
        for (final seg in band.segments.skip(1)) {
          path.lineTo(seg.x * scale, seg.y * scale);
        }
        canvas.drawPath(path, bandPaint);
      }
    }

    // Draw posts
    final Paint postPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    for (final post in posts) {
      canvas.drawCircle(
        Offset(post.x * scale, post.y * scale),
        22 * scale,
        postPaint,
      );
    }

    // Draw balls
    final Paint ballPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    const double logicalRadius = 18;
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