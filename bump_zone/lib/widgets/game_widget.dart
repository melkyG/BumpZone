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
  final double deltaT = 0.004; // Smaller time step (~250 FPS per sub-step)
  final int subSteps = 4; // Number of sub-steps per frame
  final double sideLength = 400.0;
  final int numPtsPerSide = 10;

  @override
  void initState() {
    super.initState();
    // Initialize the arena
    arena = Arena(
      sideLength: sideLength,
      numPtsPerSide: numPtsPerSide,
      topLeft: Vector2(50.0, 50.0),
    );
    // Initialize the ball
    ball = Ball(
      position: Vector2(250.0, 250.0),
      velocity: Vector2(150.0, 75.0),
      mass: 5.0, // Heavier ball
      radius: 15.0,
    );
    // Set up game loop
    controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1), // Run indefinitely
    )..addListener(() {
        // Perform multiple sub-steps per frame
        for (int i = 0; i < subSteps; i++) {
          ball.update(deltaT);
          arena.update(deltaT, ball);
        }
        setState(() {});
      });
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 500,
        height: 500,
        color: Colors.grey[200],
        child: CustomPaint(
          painter: GamePainter(arena: arena, ball: ball),
        ),
      ),
    );
  }
}