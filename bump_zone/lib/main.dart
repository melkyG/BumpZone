import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: GameWidget()));
  }
}

class GameWidget extends StatefulWidget {
  const GameWidget({super.key});

  @override
  State<GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> with TickerProviderStateMixin {
  late AnimationController _controller;
  List<Ball> balls = [];
  Rect deathZone = Rect.fromLTWH(50, 50, 300, 300);
  Rect elasticZone = Rect.fromLTWH(150, 150, 100, 100);
  double elasticStretch = 0;
  final Random random = Random();
  Ball? playerBall;

  @override
  void initState() {
    super.initState();
    // Initialize balls
    for (int i = 0; i < 5; i++) {
      double x = 150 + random.nextDouble() * 50;
      double y = 150 + random.nextDouble() * 50;
      double dx = (random.nextDouble() - 0.5) * 4;
      double dy = (random.nextDouble() - 0.5) * 4;
      Color color =
          i == 0 ? Colors.red : Colors.accents[i % Colors.accents.length];
      Ball ball = Ball(
        x: x,
        y: y,
        dx: dx,
        dy: dy,
        radius: i == 0 ? 10 : 8,
        color: color,
      );
      balls.add(ball);
      if (i == 0) playerBall = ball; // First ball is the player ball
    }

    // Animation controller for game loop
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(() {
      updatePhysics();
      setState(() {});
    });
    _controller.forward();
  }

  void updatePhysics() {
    // Update ball positions
    for (var ball in balls) {
      ball.x += ball.dx;
      ball.y += ball.dy;

      // Check collision with elastic zone
      Rect expandedElasticZone = elasticZone.inflate(elasticStretch);
      if (expandedElasticZone.contains(Offset(ball.x, ball.y))) {
        // Ball is inside or hitting the elastic zone
        if (ball.x - ball.radius < expandedElasticZone.left) {
          ball.dx = -ball.dx;
          ball.x = expandedElasticZone.left + ball.radius;
          elasticStretch += 2; // Stretch the elastic zone
        } else if (ball.x + ball.radius > expandedElasticZone.right) {
          ball.dx = -ball.dx;
          ball.x = expandedElasticZone.right - ball.radius;
          elasticStretch += 2;
        }
        if (ball.y - ball.radius < expandedElasticZone.top) {
          ball.dy = -ball.dy;
          ball.y = expandedElasticZone.top + ball.radius;
          elasticStretch += 2;
        } else if (ball.y + ball.radius > expandedElasticZone.bottom) {
          ball.dy = -ball.dy;
          ball.y = expandedElasticZone.bottom - ball.radius;
          elasticStretch += 2;
        }
      }

      // Check collision with death zone boundaries (fixed)
      if (ball.x - ball.radius < deathZone.left) {
        ball.dx = -ball.dx;
        ball.x = deathZone.left + ball.radius;
      } else if (ball.x + ball.radius > deathZone.right) {
        ball.dx = -ball.dx;
        ball.x = deathZone.right - ball.radius;
      }
      if (ball.y - ball.radius < deathZone.top) {
        ball.dy = -ball.dy;
        ball.y = deathZone.top + ball.radius;
      } else if (ball.y + ball.radius > deathZone.bottom) {
        ball.dy = -ball.dy;
        ball.y = deathZone.bottom - ball.radius;
      }
    }

    // Check ball-to-ball collisions
    for (int i = 0; i < balls.length; i++) {
      for (int j = i + 1; j < balls.length; j++) {
        Ball b1 = balls[i];
        Ball b2 = balls[j];
        double dist = sqrt(pow(b1.x - b2.x, 2) + pow(b1.y - b2.y, 2));
        if (dist < b1.radius + b2.radius) {
          // Elastic collision
          double angle = atan2(b2.y - b1.y, b2.x - b1.x);
          double speed1 = sqrt(pow(b1.dx, 2) + pow(b1.dy, 2));
          double speed2 = sqrt(pow(b2.dx, 2) + pow(b2.dy, 2));
          b1.dx = -speed1 * cos(angle);
          b1.dy = -speed1 * sin(angle);
          b2.dx = speed2 * cos(angle);
          b2.dy = speed2 * sin(angle);

          // Adjust positions to prevent sticking
          double overlap = (b1.radius + b2.radius - dist) / 2;
          b1.x -= overlap * cos(angle);
          b1.y -= overlap * sin(angle);
          b2.x += overlap * cos(angle);
          b2.y += overlap * sin(angle);
        }
      }
    }
  }

  void onTap(Offset position) {
    if (playerBall == null) return;
    // Calculate direction from player ball to tap position
    double dx = position.dx - playerBall!.x;
    double dy = position.dy - playerBall!.y;
    double magnitude = sqrt(dx * dx + dy * dy);
    if (magnitude > 0) {
      // Normalize and apply boost
      playerBall!.dx += (dx / magnitude) * 5;
      playerBall!.dy += (dy / magnitude) * 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => onTap(details.localPosition),
      child: CustomPaint(
        painter: GamePainter(balls, deathZone, elasticZone, elasticStretch),
        size: Size.infinite,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class Ball {
  double x, y;
  double dx, dy;
  double radius;
  Color color;

  Ball({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.radius,
    required this.color,
  });
}

class GamePainter extends CustomPainter {
  final List<Ball> balls;
  final Rect deathZone;
  final Rect elasticZone;
  final double elasticStretch;

  GamePainter(
    this.balls,
    this.deathZone,
    this.elasticZone,
    this.elasticStretch,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Death Zone
    final deathPaint =
        Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawRect(deathZone, deathPaint);

    // Draw Elastic Zone
    final elasticPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawRect(elasticZone.inflate(elasticStretch), elasticPaint);

    // Draw balls
    for (var ball in balls) {
      final paint = Paint()..color = ball.color;
      canvas.drawCircle(Offset(ball.x, ball.y), ball.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
