import '../models/ball.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/hud.dart';
import 'package:bump_zone/network/websocket.dart';
import 'package:bump_zone/network/arena_binary.dart'; // <-- Add this
import 'dart:typed_data'; // Add this at the top with other imports
import 'package:flutter/services.dart'; // <-- Add this import for RawKeyboardListener and LogicalKeyboardKey
import 'package:flutter/rendering.dart'; // Add this import for mouseTracker

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
  double _arenaLogicalSize = 2500.0;

  // Band settings state (add these fields)
  double _springConstant = 10.0; // <-- This is just a default, will be overwritten by server
  double _dampingCoeff = 1.0;
  double _mass = 1.0;
  double _restitution = 0.85;
  int _segmentsPerSide = 35;
  double _restLengthScale = 0.35;

  // Smooth camera offset
  Offset? _smoothedCameraOffset; // Add this field

  // Store the color picked by the client as the "myBallColor"
  Color? _myBallColor;

  // Fallback color map for balls
  final Map<String, Color> _lastBallColors = {}; // Add this

  // Store the last pointer position in global (screen) coordinates
  Offset? _lastPointerGlobal; // Add this

  // Stamina state
  double? _myStamina; // Add this to store stamina percent (0.0 - 1.0)

  // Camera zoom factor (set manually here)
  double _cameraZoom = 1.5; // Set to >1.0 to zoom in, <1.0 to zoom out, 1.0 is default

  // Track burst request
  bool _pendingBurst = false;

  // Convert global pointer position to logical arena coordinates
  Offset _getLogicalFromGlobal(Offset globalPosition) {
    final RenderBox? box = _arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    final Offset local = box.globalToLocal(globalPosition);

    final double scale = box.size.width / _arenaLogicalSize;
    final Offset cameraOffset = _smoothedCameraOffset ??
        Offset(_arenaLogicalSize / 2, _arenaLogicalSize / 2);

    final double logicalX = (local.dx - box.size.width / 2) / scale + cameraOffset.dx;
    final double logicalY = (local.dy - box.size.height / 2) / scale + cameraOffset.dy;
    return Offset(logicalX, logicalY);
  }

  void _startSendingMovement(Offset logicalTarget, [Offset? globalPosition]) {
    _lastPointerLogical = logicalTarget;
    if (globalPosition != null) {
      _lastPointerGlobal = globalPosition;
    }
    // Wait until _myPlayerId is set before starting movement
    if (_myPlayerId == null) {
      print('No playerId yet, delaying movement start.');
      return;
    }
    _moveTimer?.cancel();
    _moveTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      // Always recalculate logical target from the latest global pointer position
      if (_lastPointerGlobal != null) {
        final logical = _getLogicalFromGlobal(_lastPointerGlobal!);
        _sendMovementTo(logical);
      }
    });
    _sendMovementTo(logicalTarget); // Send immediately
  }

  void _updateSendingMovement(Offset logicalTarget, [Offset? globalPosition]) {
    _lastPointerLogical = logicalTarget;
    if (globalPosition != null) {
      _lastPointerGlobal = globalPosition;
    }
  }

  void _stopSendingMovement() {
    _moveTimer?.cancel();
    _moveTimer = null;
    _lastPointerLogical = null;
    _lastPointerGlobal = null;
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
        // Update myBallColor if my player is in the list
        final myPlayer = players.cast<dynamic?>().firstWhere(
          (p) {
            dynamic playerIdValue;
            try {
              playerIdValue = (p as dynamic)['playerId'];
            } catch (_) {
              try {
                playerIdValue = (p as dynamic).playerId;
              } catch (_) {
                playerIdValue = null;
              }
            }
            return playerIdValue == _myPlayerId;
          },
          orElse: () => null,
        );
        if (myPlayer != null) {
          dynamic colorValue;
          try {
            colorValue = (myPlayer as dynamic)['color'];
          } catch (_) {
            try {
              colorValue = (myPlayer as dynamic).color;
            } catch (_) {
              colorValue = null;
            }
          }
          if (colorValue is String && colorValue.length == 9 && colorValue.startsWith('#')) {
            try {
              _myBallColor = Color(int.parse(colorValue.substring(1), radix: 16));
            } catch (_) {}
          }
        }
      });
    };
    widget.webSocketService.onArenaUpdate = (arena) {
      //print('[DEBUG] Arena bands received: ${arena.bands.length}');
      if (arena.bands.isNotEmpty) {
        //print('[DEBUG] First band segment count: ${arena.bands[0].segments.length}');
      }
      setState(() {
        _balls = arena.balls;
        _bands = arena.bands;
        _posts = arena.posts;
        // --- Update my stamina from my ball, if present ---
        Ball? myBall;
        try {
          myBall = arena.balls.firstWhere((b) => b.id == _myPlayerId);
        } catch (_) {
          myBall = null;
        }
        if (myBall != null && myBall.stamina != null) {
          _myStamina = myBall.stamina;
          print('[DEBUG] (onArenaUpdate) myBall.stamina: ${myBall.stamina}');
        } else {
          print('[DEBUG] (onArenaUpdate) myBall or stamina is null');
        }
        // Camera smoothing: update target position here
        final Offset target = (myBall != null)
            ? Offset(myBall.x, myBall.y)
            : Offset(_arenaLogicalSize / 2, _arenaLogicalSize / 2);

        // --- Camera smoothing factor: tweak this value for acceleration/lag ---
        const double smoothing = 0.2; // <-- Increase for snappier, decrease for more lag
        // ---------------------------------------------------------------
        if (_smoothedCameraOffset == null) {
          _smoothedCameraOffset = target;
        } else {
          _smoothedCameraOffset = Offset(
            _smoothedCameraOffset!.dx + (target.dx - _smoothedCameraOffset!.dx) * smoothing,
            _smoothedCameraOffset!.dy + (target.dy - _smoothedCameraOffset!.dy) * smoothing,
          );
        }
      });
      // If user is holding/tapping, recalculate logical target from latest global pointer
      if (_lastPointerGlobal != null && _myPlayerId != null) {
        final logical = _getLogicalFromGlobal(_lastPointerGlobal!);
        _sendMovementTo(logical);
      }
    };
    widget.webSocketService.onBallsUpdate = (balls) {
      // Update last known color for each ball
      for (final ball in balls) {
        final String? colorStr = ball.color is String ? ball.color as String : null;
        if (colorStr != null && colorStr.length == 9 && colorStr.startsWith('#')) {
          try {
            _lastBallColors[ball.id] = Color(int.parse(colorStr.substring(1), radix: 16));
          } catch (_) {}
        }
      }
      setState(() {
        _balls = balls;
        // --- Also update stamina here ---
        Ball? myBall;
        try {
          myBall = balls.firstWhere((b) => b.id == _myPlayerId);
        } catch (_) {
          myBall = null;
        }
        if (myBall != null && myBall.stamina != null) {
          _myStamina = myBall.stamina;
          print('[DEBUG] (onBallsUpdate) myBall.stamina: ${myBall.stamina}');
        } else {
          print('[DEBUG] (onBallsUpdate) myBall or stamina is null');
        }
      });
    };
    widget.webSocketService.onWelcome = (playerId) {
      // If user is holding/tapping, start movement now that playerId is available
      if (_lastPointerLogical != null) {
        _startSendingMovement(_lastPointerLogical!);
      }
      // Request band settings after join
      print('[GAME] Sending getBandSettings after join'); // <-- Add this debug print
      widget.webSocketService.sendRaw({'type': 'getBandSettings'});
    };
    widget.webSocketService.onBandSettingsUpdate = (spring, damping, mass, restitution, segmentsPerSide, restLengthScale) {
      print('[GAME] onBandSettingsUpdate: $spring, $damping, $mass, $restitution, $segmentsPerSide, $restLengthScale');
      setState(() {
        _springConstant = spring;
        _dampingCoeff = damping;
        _mass = mass;
        _restitution = restitution;
        _segmentsPerSide = segmentsPerSide;
        _restLengthScale = restLengthScale;
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
    final double baseScale = (availableHeight < availableWidth)
        ? availableHeight / _arenaLogicalSize
        : availableWidth / _arenaLogicalSize;
    final double scale = baseScale * _cameraZoom; // <-- Use manual zoom factor here
    final double displaySize = _arenaLogicalSize * scale;
    final bool ready = _myPlayerId != null;

    // Find my ball
    Ball? myBall;
    try {
      myBall = _balls.firstWhere((b) => b.id == _myPlayerId);
    } catch (_) {
      myBall = null;
    }
    // Use smoothed camera offset if available
    Offset cameraOffset = _smoothedCameraOffset ??
        ((myBall != null)
            ? Offset(myBall.x, myBall.y)
            : Offset(_arenaLogicalSize / 2, _arenaLogicalSize / 2));

    // Build playerColors map from _players (playerId -> Color)
    final Map<String, Color> playerColors = {};
    for (final player in _players) {
      String? id;
      String? colorStr;
      try {
        id = (player as dynamic)['playerId'];
        colorStr = (player as dynamic)['color'];
      } catch (_) {
        try {
          id = (player as dynamic).playerId;
          colorStr = (player as dynamic).color;
        } catch (_) {
          id = null;
          colorStr = null;
        }
      }
      if (id != null && colorStr != null && colorStr.length == 9 && colorStr.startsWith('#')) {
        try {
          playerColors[id] = Color(int.parse(colorStr.substring(1), radix: 16));
        } catch (_) {}
      }
    }

    print('[DEBUG] (build) _myStamina: $_myStamina');

    return Scaffold(
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKey: (event) {
          if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
            if (!_pendingBurst) {
              _pendingBurst = true;
              Offset? pointer;
              Offset? mousePosition;
              try {
                // Fallback: Use _lastPointerGlobal if available (from last click/tap/drag)
                if (_lastPointerGlobal != null) {
                  mousePosition = _lastPointerGlobal;
                }
              } catch (_) {
                // Fallback: ignore errors, mousePosition remains null
              }
              if (mousePosition != null) {
                pointer = mousePosition;
              }
              // Fallback to center if mouse is not available
              if (pointer == null) {
                final RenderBox? box = _arenaKey.currentContext?.findRenderObject() as RenderBox?;
                if (box != null) {
                  pointer = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
                }
              }
              // --- DEBUG PRINT: Print the pointer position when burst is activated ---
              print('[BURST] Raw pointer for burst: $pointer');
              if (_myPlayerId != null) {
                Ball? myBall;
                try {
                  myBall = _balls.firstWhere((b) => b.id == _myPlayerId);
                } catch (_) {
                  myBall = null;
                }
                if (myBall != null) {
                  print('[BURST] My ball position: (${myBall.x}, ${myBall.y})');
                }
              }
              // ---------------------------------------------------------------
              if (pointer != null) {
                final logical = _getLogicalFromGlobal(pointer);
                print('[BURST] Logical burst target: $logical');
                _sendBurstTo(logical);
              }
            }
          }
          if (event is RawKeyUpEvent && event.logicalKey == LogicalKeyboardKey.space) {
            _pendingBurst = false;
          }
        },
        child: Stack(
          children: [
            // --- Add a full-screen grey background behind everything ---
            Positioned.fill(
              child: Container(color: Colors.grey[300]),
            ),
            // --- The rest of your UI ---
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (DragStartDetails details) {
                final logicalTarget = _getLogicalFromGlobal(details.globalPosition);
                _startSendingMovement(logicalTarget, details.globalPosition);
              },
              onPanUpdate: (DragUpdateDetails details) {
                final logicalTarget = _getLogicalFromGlobal(details.globalPosition);
                _updateSendingMovement(logicalTarget, details.globalPosition);
              },
              onPanEnd: (DragEndDetails details) {
                _stopSendingMovement();
              },
              onPanCancel: () {
                _stopSendingMovement();
              },
              onTapDown: (TapDownDetails details) {
                final logicalTarget = _getLogicalFromGlobal(details.globalPosition);
                _startSendingMovement(logicalTarget, details.globalPosition);
              },
              onTapUp: (TapUpDetails details) {
                _stopSendingMovement();
              },
              child: MouseRegion(
                onHover: (PointerHoverEvent event) {
                  // Only update the pointer position for burst direction
                  _lastPointerGlobal = event.position;
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
                      color: Colors.transparent,
                      child: CustomPaint(
                        size: Size(_arenaLogicalSize, _arenaLogicalSize),
                        painter: _ArenaPainter(
                          balls: _balls,
                          bands: _bands,
                          posts: _posts,
                          arenaLogicalSize: _arenaLogicalSize,
                          cameraOffset: cameraOffset,
                          playerColors: playerColors,
                          myPlayerId: _myPlayerId,
                          myBallColor: _myBallColor,
                          lastBallColors: _lastBallColors,
                        ),
                        isComplex: false,
                        willChange: false,
                      ),
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
              segmentsPerSide: _segmentsPerSide,
              restLengthScale: _restLengthScale,
              onSpringChanged: (v) {
                setState(() => _springConstant = v);
                widget.webSocketService.sendBandSettings(
                  springConstant: v,
                  dampingCoeff: _dampingCoeff,
                  mass: _mass,
                  restitution: _restitution,
                  segmentsPerSide: _segmentsPerSide,
                  restLengthScale: _restLengthScale,
                );
              },
              onDampingChanged: (v) {
                setState(() => _dampingCoeff = v);
                widget.webSocketService.sendBandSettings(
                  springConstant: _springConstant,
                  dampingCoeff: v,
                  mass: _mass,
                  restitution: _restitution,
                  segmentsPerSide: _segmentsPerSide,
                  restLengthScale: _restLengthScale,
                );
              },
              onMassChanged: (v) {
                setState(() => _mass = v);
                widget.webSocketService.sendBandSettings(
                  springConstant: _springConstant,
                  dampingCoeff: _dampingCoeff,
                  mass: v,
                  restitution: _restitution,
                  segmentsPerSide: _segmentsPerSide,
                  restLengthScale: _restLengthScale,
                );
              },
              onRestitutionChanged: (v) {
                setState(() => _restitution = v);
                widget.webSocketService.sendBandSettings(
                  springConstant: _springConstant,
                  dampingCoeff: _dampingCoeff,
                  mass: _mass,
                  restitution: v,
                  segmentsPerSide: _segmentsPerSide,
                  restLengthScale: _restLengthScale,
                );
              },
              onSegmentsChanged: (v) {
                setState(() => _segmentsPerSide = v);
                widget.webSocketService.sendBandSettings(
                  springConstant: _springConstant,
                  dampingCoeff: _dampingCoeff,
                  mass: _mass,
                  restitution: _restitution,
                  segmentsPerSide: v,
                  restLengthScale: _restLengthScale,
                );
              },
              onRestLengthScaleChanged: (v) {
                setState(() => _restLengthScale = v);
                widget.webSocketService.sendBandSettings(
                  springConstant: _springConstant,
                  dampingCoeff: _dampingCoeff,
                  mass: _mass,
                  restitution: _restitution,
                  segmentsPerSide: _segmentsPerSide,
                  restLengthScale: v,
                );
              },
              onResetToDefault: () {
                widget.webSocketService.sendRaw({'type': 'resetBandSettings'});
              },
              onRespawn: () {
                widget.webSocketService.sendRaw({'type': 'respawn'});
              },
              staminaPercent: _myStamina, // --- Add staminaPercent to HUD ---
            ),
            if (!ready)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _sendBurstTo(Offset logicalTarget) {
    if (_myPlayerId == null) return;
    Ball? myBall;
    try {
      myBall = _balls.firstWhere((b) => b.id == _myPlayerId);
    } catch (_) {
      myBall = null;
    }
    if (myBall == null) return;

    final double dx = logicalTarget.dx - myBall.x;
    final double dy = logicalTarget.dy - myBall.y;
    final double length = math.sqrt(dx * dx + dy * dy);
    final double dirX = length > 0 ? dx / length : 0;
    final double dirY = length > 0 ? dy / length : 0;
    print('Burst raw: dx=$dx dy=$dy, normalized: ($dirX, $dirY)'); // <-- Add this debug print
    // Send burst flag to server
    widget.webSocketService.sendMovementWithBurst(dirX, dirY, true);
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
  final Map<String, Color> playerColors;
  final String? myPlayerId;      // Add this
  final Color? myBallColor;      // Add this
  final Map<String, Color> lastBallColors; // Add this

  _ArenaPainter({
    required this.balls,
    required this.bands,
    required this.posts,
    required this.arenaLogicalSize,
    required this.cameraOffset,
    this.playerColors = const {},
    this.myPlayerId,             // Add this
    this.myBallColor,            // Add this
    required this.lastBallColors, // Add this
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / arenaLogicalSize;
    final double camX = (cameraOffset.dx.isNaN || cameraOffset.dx.isInfinite)
        ? arenaLogicalSize / 2
        : cameraOffset.dx;
    final double camY = (cameraOffset.dy.isNaN || cameraOffset.dy.isInfinite)
        ? arenaLogicalSize / 2
        : cameraOffset.dy;

    // 1. Fill the entire canvas with grey (background, fixed to canvas)
    final Paint backgroundPaint = Paint()..color = Colors.grey[300]!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // 2. Compute the top-left of the arena in screen coordinates
    final double arenaLeft = size.width / 2 - camX * scale;
    final double arenaTop = size.height / 2 - camY * scale;
    final double arenaSizePx = arenaLogicalSize * scale;

    // 3. Draw the arena background (white) at the correct translated position
    final Paint arenaBgPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(arenaLeft, arenaTop, arenaSizePx, arenaSizePx),
      arenaBgPaint,
    );

    // 4. Now translate for camera and draw all arena content
    canvas.save();
    canvas.translate(
      size.width / 2 - camX * scale,
      size.height / 2 - camY * scale,
    );

    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, arenaLogicalSize * scale, arenaLogicalSize * scale),
      borderPaint,
    );

    // Boxing ring: alternate band colors (blue and red)
    final List<Color> bandColors = [
      Colors.blue,
      Colors.red,
      Colors.blue,
      Colors.red,
    ];
    for (int i = 0; i < bands.length; i++) {
      final band = bands[i];
      if (band.segments.isNotEmpty) {
        final first = band.segments[0];
        final path = Path();
        path.moveTo(first.x * scale, first.y * scale);
        for (final seg in band.segments.skip(1)) {
          path.lineTo(seg.x * scale, seg.y * scale);
        }
        final Paint bandPaint = Paint()
          ..color = bandColors[i % bandColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawPath(path, bandPaint);
      }
    }

    // Boxing ring: 2 blue posts and 2 red posts (diagonally opposite)
    final List<Color> postColors = [
      Colors.blue,
      Colors.red,
      Colors.blue,
      Colors.red,
    ];
    for (int i = 0; i < posts.length; i++) {
      final post = posts[i];
      final Paint postPaint = Paint()
        ..color = postColors[i % postColors.length]
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(post.x * scale, post.y * scale),
        22 * scale,
        postPaint,
      );
    }

    const double logicalRadius = 18;
    // Draw balls with player color from playerColors map or ball.color only (no fallback)
    for (final ball in balls) {
      Color? drawColor;
      final String? colorStr = ball.color is String ? ball.color as String : null;
      if (colorStr != null && colorStr.length == 9 && colorStr.startsWith('#')) {
        try {
          drawColor = Color(int.parse(colorStr.substring(1), radix: 16));
        } catch (_) {
          drawColor = null;
        }
      }
      if (drawColor == null && lastBallColors[ball.id] != null) {
        drawColor = lastBallColors[ball.id];
      }
      if (myPlayerId != null && ball.id == myPlayerId && myBallColor != null) {
        drawColor = myBallColor!;
      }
      if (drawColor != null) {
        final Paint ballPaint = Paint()
          ..color = drawColor
          ..style = PaintingStyle.fill;
        final Paint borderPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6 * scale; // Scaled border width
        final Offset center = Offset(ball.x * scale, ball.y * scale);
        final double radius = logicalRadius * scale;
        canvas.drawCircle(center, radius, ballPaint);
        canvas.drawCircle(center, radius, borderPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}