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
  double _arenaLogicalSize = 3000.0;

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
  final Map<String, double> _lastBallMasses = {}; // Add this map for masses

  // Store the last pointer position in global (screen) coordinates
  Offset? _lastPointerGlobal; // Add this

  // Stamina state
  double? _myStamina; // Add this to store stamina percent (0.0 - 1.0)

  // Camera zoom factor (set manually here)
  double _cameraZoom = 1.5; // Set to >1.0 to zoom in, <1.0 to zoom out, 1.0 is default

  // Track burst request
  bool _pendingBurst = false;

  // Smooth zoom factor
  double? _smoothedZoom; // Add this field

  // Convert global pointer position to logical arena coordinates
  Offset _getLogicalFromGlobal(Offset globalPosition) {
    final RenderBox? box = _arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    // --- FIX: Use box.localToGlobal(Offset.zero) to get the arena's top-left in global coordinates ---
    final Offset arenaTopLeftGlobal = box.localToGlobal(Offset.zero);
    final double scale = box.size.width / _arenaLogicalSize;
    final Offset cameraOffset = _smoothedCameraOffset ??
        Offset(_arenaLogicalSize / 2, _arenaLogicalSize / 2);

    // Calculate local position relative to the arena widget
    final Offset local = globalPosition - arenaTopLeftGlobal;

    final double logicalX = (local.dx - box.size.width / 2) / scale + cameraOffset.dx;
    final double logicalY = (local.dy - box.size.height / 2) / scale + cameraOffset.dy;
    return Offset(logicalX, logicalY);
  }

  void _startSendingMovement(Offset logicalTarget, [Offset? globalPosition]) {
    _lastPointerLogical = logicalTarget;
    if (globalPosition != null) {
      _lastPointerGlobal = globalPosition;
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

    final double dx = logicalTarget.dx - myBall.x;
    final double dy = logicalTarget.dy - myBall.y;
    final double length = math.sqrt(dx * dx + dy * dy);
    final double dirX = length > 0 ? dx / length : 0;
    final double dirY = length > 0 ? dy / length : 0;
    widget.webSocketService.sendMovement(dirX, dirY);
  }

  @override
  void initState() {
    super.initState();
    widget.webSocketService.onPlayerListUpdate = (players) {
      setState(() {
        _players = players;
        // Debug: Log all players and their colors
        for (final player in players) {
          print('Player: id=${player.id}, username=${player.username}, color=${player.color}');
        }
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
      // Only send movement if the user is actively holding/tapping (moveTimer is running)
      if (_moveTimer != null && _lastPointerGlobal != null && _myPlayerId != null) {
        final logical = _getLogicalFromGlobal(_lastPointerGlobal!);
        _sendMovementTo(logical);
      }
    };
    widget.webSocketService.onBallsUpdate = (balls) {
      _onBallsUpdate(balls);
    };
    widget.webSocketService.onWelcome = (playerId) {
      // If user is holding/tapping, start movement now that playerId is available
      if (_lastPointerLogical != null) {
        _startSendingMovement(_lastPointerLogical!);
      }
      widget.webSocketService.sendRaw({'type': 'getBandSettings'});
    };
    widget.webSocketService.onBandSettingsUpdate = (spring, damping, mass, restitution, segmentsPerSide, restLengthScale) {
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

    // Find my ball and calculate dynamic zoom based on mass
    Ball? myBall;
    try {
      myBall = _balls.firstWhere((b) => b.id == _myPlayerId);
    } catch (_) {
      myBall = null;
    }

    // Calculate target zoom based on mass, using cached mass if available
    double targetZoom = 4; // Default zoom (changed from 2.5 to 3.0 for more zoomed in start)
    if (myBall != null) {
      // Use cached mass if available, otherwise use current mass
      final double mass = myBall.mass ?? _lastBallMasses[myBall.id] ?? 2.5;
      // Update cache with current mass if available
      if (myBall.mass != null) {
        _lastBallMasses[myBall.id] = myBall.mass!;
      }
      // Invert the mass ratio to zoom out as mass increases
      // Clamp between 1.5 and 3.0 to keep camera closer
      targetZoom = 4.0 / (mass / 2.5).clamp(0.5, 4.0);
      // Ensure zoom stays within our desired range
      targetZoom = targetZoom.clamp(1.8, 4.0);
    }

    // Smooth zoom transition
    const double zoomSmoothing = 0.1; // Adjust this value to control zoom transition speed
    if (_smoothedZoom == null) {
      _smoothedZoom = targetZoom;
    } else {
      _smoothedZoom = _smoothedZoom! + (targetZoom - _smoothedZoom!) * zoomSmoothing;
    }

    final double scale = baseScale * _smoothedZoom!; // Use smoothed zoom factor here
    final double displaySize = _arenaLogicalSize * scale;
    final bool ready = _myPlayerId != null;

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
              if (_myPlayerId != null) {
                Ball? myBall;
                try {
                  myBall = _balls.firstWhere((b) => b.id == _myPlayerId);
                } catch (_) {
                  myBall = null;
                }
              }
              // ---------------------------------------------------------------
              if (pointer != null) {
                final logical = _getLogicalFromGlobal(pointer);
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
                  // DO NOT call _startSendingMovement or _updateSendingMovement here!
                },
                // Prevent MouseRegion from activating gestures unless a button is pressed
                child: Listener(
                  onPointerDown: (_) {}, // Needed to allow GestureDetector to work inside MouseRegion
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
                            lastBallMasses: _lastBallMasses,
                          ),
                          isComplex: false,
                          willChange: false,
                        ),
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
              onRespawn: _handleRespawn,
              onSpawnBot: _handleSpawnBot,
              staminaPercent: _myStamina,
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
    // Send burst flag to server
    widget.webSocketService.sendMovementWithBurst(dirX, dirY, true);

    // Only stop sending movement if the user is NOT actively holding/tapping
    if (_moveTimer == null || _lastPointerGlobal == null) {
      _stopSendingMovement();
    }
  }

  void _handleRespawn() {
    widget.webSocketService.sendRaw({'type': 'respawn'});
  }

  void _handleSpawnBot() {
    widget.webSocketService.sendRaw({'type': 'spawnBot'});
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    super.dispose();
  }

  void _onBallsUpdate(List<Ball> balls) {
    print('_onBallsUpdate received ${balls.length} balls: ${balls.map((b) => '${b.id}').join(', ')}');
    // Update last known color and mass for each ball
    for (final ball in balls) {
      final bool isBot = ball.id.startsWith('Bot');
      print('Ball update: id=${ball.id}, isBot=$isBot, color=${ball.color}, mass=${ball.mass}');
      
      // Only update color if it's provided (from JSON message)
      if (ball.color is String && ball.color.toString().startsWith('#')) {
        try {
          final colorStr = ball.color.toString();
          // If color is 6 digits (#RRGGBB), add alpha channel
          // If color is 8 digits (#AARRGGBB), use as is
          final colorHex = colorStr.length == 7 ? '#ff${colorStr.substring(1)}' : colorStr;
          final color = Color(int.parse(colorHex.substring(1), radix: 16));
          _lastBallColors[ball.id] = color;
          print('Updated ball color from JSON: id=${ball.id}, isBot=$isBot, color=${ball.color}, parsedColor=$color');
        } catch (e) {
          print('Failed to parse color from JSON: ${ball.color}, error=$e');
        }
      } else {
        print('No color update for ball ${ball.id}: color=${ball.color}');
      }
      
      // Store last known mass if available
      if (ball.mass != null) {
        _lastBallMasses[ball.id] = ball.mass!;
      }
    }
    setState(() {
      _balls = balls;
    });
    print('After _onBallsUpdate, _balls has ${_balls.length} balls: ${_balls.map((b) => '${b.id}(${b.color})').join(', ')}');
    print('Current _lastBallColors: ${_lastBallColors.entries.map((e) => '${e.key}: ${e.value}').join(', ')}');
  }

  void _updateCamera() {
    if (_myPlayerId == null) return;
    Ball? myBall;
    try {
      myBall = _balls.firstWhere((b) => b.id == _myPlayerId);
    } catch (_) {
      return;
    }

    // Update camera position to follow ball
    _smoothedCameraOffset = Offset(myBall.x, myBall.y);

    // Update zoom based on mass
    final mass = myBall.mass ?? _lastBallMasses[_myPlayerId] ?? 2.5;
    // Adjust zoom calculation to keep camera closer when ball is large
    final targetZoom = 3.0 / (mass / 2.5).clamp(0.5, 2.5);
    _smoothedZoom = (_smoothedZoom ?? 1.0) + (targetZoom - (_smoothedZoom ?? 1.0)) * 0.1;
  }
}

class _ArenaPainter extends CustomPainter {
  final List<Ball> balls;
  final List<Band> bands;
  final List<BandSegment> posts;
  final double arenaLogicalSize;
  final Offset cameraOffset;
  final Map<String, Color> playerColors;
  final String? myPlayerId;
  final Color? myBallColor;
  final Map<String, Color> lastBallColors;
  final Map<String, double> lastBallMasses;

  _ArenaPainter({
    required this.balls,
    required this.bands,
    required this.posts,
    required this.arenaLogicalSize,
    required this.cameraOffset,
    this.playerColors = const {},
    this.myPlayerId,
    this.myBallColor,
    required this.lastBallColors,
    required this.lastBallMasses,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('Painter received ${balls.length} balls: ${balls.map((b) => '${b.id}(${b.color})').join(', ')}');
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

    const double logicalRadius = 18; // Base radius
    // Draw balls
    for (final ball in balls) {
      final bool isBot = ball.id.startsWith('Bot');
      final double mass = ball.mass ?? lastBallMasses[ball.id] ?? 2.5;
      final double radius = logicalRadius * (mass / 2.5) * scale;
      final Offset center = Offset(ball.x * scale, ball.y * scale);
      
      // Get color from cache or default
      final ballColor = lastBallColors[ball.id] ?? Colors.blue;
      print('Drawing ball: id=${ball.id}, isBot=$isBot, cachedColor=$ballColor, hasColor=${lastBallColors.containsKey(ball.id)}');

      // Draw the ball
      final paint = Paint()
        ..color = ballColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
      
      // Draw border
      final borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 * scale;
      canvas.drawCircle(center, radius, borderPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}