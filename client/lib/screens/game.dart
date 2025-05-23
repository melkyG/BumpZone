import 'package:flutter/material.dart';
import 'package:bump_zone/game/arena.dart';
import 'package:bump_zone/game/ball.dart';
import 'package:bump_zone/network/websocket.dart';
import 'package:bump_zone/screens/game_painter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

class GameScreen extends StatelessWidget {
  final WebSocketService webSocketService;

  const GameScreen({super.key, required this.webSocketService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('Game Screen (Placeholder)')),
    );
  }
}

class GameWidget extends StatefulWidget {
  final String username;
  final String playerId;
  final WebSocketService webSocketService;

  const GameWidget({
    super.key,
    required this.username,
    required this.playerId,
    required this.webSocketService,
  });

  @override
  _GameWidgetState createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> with TickerProviderStateMixin {
  late Arena arena;
  late Ball ball;
  late AnimationController controller;
  final double deltaT = 0.002;
  final int subSteps = 8;
  final double sideLength = 700.0;
  final double containerWidth = 1000.0;
  final double containerHeight = 1000.0;
  int numPtsPerSide = 35;

  // Settings values
  double springConstant = 350.0;
  double dampingCoeff = 0.08;
  double mass = 0.04;
  double coefficientOfRestitution = 0.85;
  double restLengthScale = 0.35;

  // Cursor force
  bool isClicking = false;
  Vector2 cursorPosition = Vector2.zero();
  double forceConstant = 10.0;
  double clickDuration = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeArena();
    ball = Ball(
      position: Vector2(400.0, 300.0),
      velocity: Vector2(200.0, 85.0),
      mass: 4.0,
      radius: 25.0,
    );

    // Listen for WebSocket updates
    widget.webSocketService.onStateUpdate = (players, playerId) {
      for (var player in players) {
        if (player.id == widget.playerId) {
          ball.position = Vector2(player.positionX, player.positionY);
          ball.velocity = Vector2(player.velocityX, player.velocityY);
        }
      }
    };

    controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(() {
      for (int i = 0; i < subSteps; i++) {
        if (isClicking) {
          clickDuration += deltaT;
          final direction = cursorPosition - ball.position;
          final distance = direction.length;
          final forceScale = clickDuration.clamp(0.0, 2.0);
          ball.force = direction.normalized() * forceConstant * forceScale * distance.clamp(0, 100);
          widget.webSocketService.sendMovement(ball.velocity.x, ball.velocity.y);
        } else {
          clickDuration = 0.0;
        }

        ball.update(deltaT);
        arena.update(deltaT, ball);
      }
      setState(() {});
    });
    controller.forward();
  }

  void _initializeArena() {
    final topLeft = Vector2(
      (containerWidth - sideLength) / 2,
      (containerHeight - sideLength) / 2,
    );
    arena = Arena(
      sideLength: sideLength,
      numPtsPerSide: numPtsPerSide,
      topLeft: topLeft,
    );
    arena.updateBandParameters(
      springConstant: springConstant,
      dampingCoeff: dampingCoeff,
      mass: mass,
      restLengthScale: restLengthScale,
      coefficientOfRestitution: coefficientOfRestitution,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    widget.webSocketService.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onPanDown: (details) {
                        setState(() {
                          isClicking = true;
                          cursorPosition = Vector2(
                            details.localPosition.dx,
                            details.localPosition.dy,
                          );
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          cursorPosition = Vector2(
                            details.localPosition.dx,
                            details.localPosition.dy,
                          );
                        });
                      },
                      onPanEnd: (_) {
                        setState(() {
                          isClicking = false;
                        });
                      },
                      child: Container(
                        width: 1000,
                        height: 1000,
                        color: Colors.grey[200],
                        child: CustomPaint(
                          painter: GamePainter(
                            arena: arena,
                            ball: ball,
                            username: widget.username,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 500,
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.white.withOpacity(0.8),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Band Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSlider(
                          label: 'Spring Constant',
                          value: springConstant,
                          min: 0.0,
                          max: 10000.0,
                          divisions: 900,
                          onChanged: (value) {
                            setState(() {
                              springConstant = value;
                              arena.updateBandParameters(springConstant: value);
                            });
                          },
                        ),
                        _buildSlider(
                          label: 'Damping Coefficient',
                          value: dampingCoeff,
                          min: 0.0,
                          max: 50.0,
                          divisions: 500,
                          onChanged: (value) {
                            setState(() {
                              dampingCoeff = value;
                              arena.updateBandParameters(dampingCoeff: value);
                            });
                          },
                        ),
                        _buildSlider(
                          label: 'Node Mass',
                          value: mass,
                          min: 0.01,
                          max: 5.0,
                          divisions: 200,
                          onChanged: (value) {
                            setState(() {
                              mass = value;
                              arena.updateBandParameters(mass: value);
                            });
                          },
                        ),
                        _buildSlider(
                          label: 'Coefficient of Restitution',
                          value: coefficientOfRestitution,
                          min: 0.01,
                          max: 1.0,
                          divisions: 200,
                          onChanged: (value) {
                            setState(() {
                              coefficientOfRestitution = value;
                              arena.updateBandParameters(
                                coefficientOfRestitution: value,
                              );
                            });
                          },
                        ),
                        _buildSlider(
                          label: 'Rest Length Scale',
                          value: restLengthScale,
                          min: 0.0,
                          max: 3.0,
                          divisions: 100,
                          onChanged: (value) {
                            setState(() {
                              restLengthScale = value;
                              arena.updateBandParameters(
                                restLengthScale: value,
                              );
                            });
                          },
                        ),
                        _buildSlider(
                          label: 'Nodes per Side',
                          value: numPtsPerSide.toDouble(),
                          min: 5.0,
                          max: 75.0,
                          divisions: 70,
                          onChanged: (value) {
                            setState(() {
                              numPtsPerSide = value.round();
                              _initializeArena();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.black, size: 24),
                onPressed: () {
                  // TODO: Implement settings navigation
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${value.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}