
import 'package:flutter/material.dart';
import '../models/arena.dart';
import '../models/ball.dart';
import 'game_painter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

class GameWidget extends StatefulWidget {
  const GameWidget({super.key});

  @override
  _GameWidgetState createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> with TickerProviderStateMixin {
  late Arena arena;
  late Ball ball;
  late AnimationController controller;
  final double deltaT = 0.001;
  final int subSteps = 16;
  final double sideLength = 700.0;
  final double containerWidth = 1000.0;
  final double containerHeight = 1000.0;
  int numPtsPerSide = 30;

  // Settings values
  double springConstant = 150.0;
  double dampingCoeff = 0.1;
  double mass = 0.01;
  double coefficientOfRestitution = 0.01;
  double restLengthScale = 0.0;

  // Cursor force
  bool isClicking = false;
  Vector2 cursorPosition = Vector2.zero();
  final double forceConstant = 10.0;

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
    controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(() {
        for (int i = 0; i < subSteps; i++) {
          // Apply cursor force if clicking
          if (isClicking) {
            final direction = cursorPosition - ball.position;
            final distance = direction.length;
            ball.force = direction.normalized() * forceConstant * distance.clamp(0, 100);
          }
          ball.update(deltaT);
          arena.update(deltaT, ball);
        }
        setState(() {});
      });
    controller.forward();
  }

  void _initializeArena() {
    // Center the arena in the container
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Row(
        children: [
          // Game canvas
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
                    painter: GamePainter(arena: arena, ball: ball),
                  ),
                ),
              ),
            ),
          ),
          // Settings panel
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    max: 50,
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
                    max: 5,
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
                        arena.updateBandParameters(coefficientOfRestitution: value);
                      });
                    },
                  ),
                  _buildSlider(
                    label: 'Rest Length Scale',
                    value: restLengthScale,
                    min: 0.0,
                    max: 3,
                    divisions: 100,
                    onChanged: (value) {
                      setState(() {
                        restLengthScale = value;
                        arena.updateBandParameters(restLengthScale: value);
                      });
                    },
                  ),
                  _buildSlider(
                    label: 'Nodes per Side',
                    value: numPtsPerSide.toDouble(),
                    min: 5,
                    max: 75,
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