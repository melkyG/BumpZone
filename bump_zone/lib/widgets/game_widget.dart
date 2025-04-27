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
  final double deltaT = 0.002;
  final int subSteps = 8;
  final double sideLength = 400.0;
  int numPtsPerSide = 15;

  // Settings values
  double springConstant = 1000.0;
  double dampingCoeff = 5;
  double mass = 1;
  double coefficientOfRestitution = 1.0;
  double restLengthScale = 0.95;

  @override
  void initState() {
    super.initState();
    _initializeArena();
    ball = Ball(
      position: Vector2(150.0, 150.0),
      velocity: Vector2(200.0, 85.0),
      mass: 10.0,
      radius: 30.0,
    );
    controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(() {
        for (int i = 0; i < subSteps; i++) {
          ball.update(deltaT);
          arena.update(deltaT, ball);
        }
        setState(() {});
      });
    controller.forward();
  }

  void _initializeArena() {
    arena = Arena(
      sideLength: sideLength,
      numPtsPerSide: numPtsPerSide,
      topLeft: Vector2(50.0, 50.0),
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
      appBar: AppBar(
        title: const Text('Elastic Band Game'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Band Settings',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            _buildSlider(
              label: 'Spring Constant',
              value: springConstant,
              min: 0.0,
              max: 1000.0,
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
              min: 0.9,
              max: 1.0,
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
                  _initializeArena(); // Rebuild arena with new numPtsPerSide
                });
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Container(
          width: 500,
          height: 500,
          color: Colors.grey[200],
          child: CustomPaint(
            painter: GamePainter(arena: arena, ball: ball),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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