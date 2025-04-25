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
  double stretchLeft = 0;
  double stretchRight = 0;
  double stretchTop = 0;
  double stretchBottom = 0;
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
    // Gradually reduce the stretch (revert to fixed decay rate)
    if (stretchLeft > 0) {
      stretchLeft -= 0.1; // Fixed decay rate as before
      if (stretchLeft < 0) stretchLeft = 0;
    }
    if (stretchRight > 0) {
      stretchRight -= 0.1;
      if (stretchRight < 0) stretchRight = 0;
    }
    if (stretchTop > 0) {
      stretchTop -= 0.1;
      if (stretchTop < 0) stretchTop = 0;
    }
    if (stretchBottom > 0) {
      stretchBottom -= 0.1;
      if (stretchBottom < 0) stretchBottom = 0;
    }

    // Update ball positions and check for collisions
    for (int i = balls.length - 1; i >= 0; i--) {
      var ball = balls[i];
      ball.x += ball.dx;
      ball.y += ball.dy;

      // Check collision with elastic zone
      Rect expandedElasticZone = Rect.fromLTRB(
        elasticZone.left - stretchLeft,
        elasticZone.top - stretchTop,
        elasticZone.right + stretchRight,
        elasticZone.bottom + stretchBottom,
      );

      // Check if the ball touches the death zone with a small tolerance
      bool ballDies = false;
      const tolerance = 1.0; // Small tolerance for death zone collision
      if (ball.x - ball.radius <= deathZone.left + tolerance &&
          stretchLeft >= 100 - tolerance) {
        ballDies = true;
      } else if (ball.x + ball.radius >= deathZone.right - tolerance &&
          stretchRight >= 100 - tolerance) {
        ballDies = true;
      }
      if (ball.y - ball.radius <= deathZone.top + tolerance &&
          stretchTop >= 100 - tolerance) {
        ballDies = true;
      } else if (ball.y + ball.radius >= deathZone.bottom - tolerance &&
          stretchBottom >= 100 - tolerance) {
        ballDies = true;
      }

      if (ballDies) {
        balls.removeAt(i);
        if (ball == playerBall) playerBall = null;
        continue;
      }

      // Ensure the ball stays within the elastic zone
      if (ball.x - ball.radius < expandedElasticZone.left) {
        ball.dx = -ball.dx;
        ball.x = expandedElasticZone.left + ball.radius;
        stretchLeft += 10;
      } else if (ball.x + ball.radius > expandedElasticZone.right) {
        ball.dx = -ball.dx;
        ball.x = expandedElasticZone.right - ball.radius;
        stretchRight += 10;
      }
      if (ball.y - ball.radius < expandedElasticZone.top) {
        ball.dy = -ball.dy;
        ball.y = expandedElasticZone.top + ball.radius;
        stretchTop += 10;
      } else if (ball.y + ball.radius > expandedElasticZone.bottom) {
        ball.dy = -ball.dy;
        ball.y = expandedElasticZone.bottom - ball.radius;
        stretchBottom += 10;
      }

      // Cap the stretch so it doesn't exceed the death zone's inner edge
      if (stretchLeft > 100) stretchLeft = 100;
      if (stretchRight > 100) stretchRight = 100;
      if (stretchTop > 100) stretchTop = 100;
      if (stretchBottom > 100) stretchBottom = 100;
    }

    // Check ball-to-ball collisions with correct elastic collision for equal masses
    for (int i = 0; i < balls.length; i++) {
      for (int j = i + 1; j < balls.length; j++) {
        Ball b1 = balls[i];
        Ball b2 = balls[j];
        double dist = sqrt(pow(b1.x - b2.x, 2) + pow(b1.y - b2.y, 2));
        if (dist < b1.radius + b2.radius) {
          // Normalize the collision vector
          double dx = b2.x - b1.x;
          double dy = b2.y - b1.y;
          double dist = sqrt(dx * dx + dy * dy);
          double nx = dx / dist;
          double ny = dy / dist;

          // Project velocities onto the normal and tangent vectors
          double v1n = b1.dx * nx + b1.dy * ny; // Normal component of b1
          double v1t_x = b1.dx - v1n * nx; // Tangential component of b1
          double v1t_y = b1.dy - v1n * ny;
          double v2n = b2.dx * nx + b2.dy * ny; // Normal component of b2
          double v2t_x = b2.dx - v2n * nx; // Tangential component of b2
          double v2t_y = b2.dy - v2n * ny;

          // For equal masses in perfectly elastic collision, swap normal components
          double v1n_new = v2n;
          double v2n_new = v1n;

          // Recombine normal and tangential components
          b1.dx = v1t_x + v1n_new * nx;
          b1.dy = v1t_y + v1n_new * ny;
          b2.dx = v2t_x + v2n_new * nx;
          b2.dy = v2t_y + v2n_new * ny;

          // Adjust positions to prevent sticking
          double overlap = (b1.radius + b2.radius - dist) / 2;
          b1.x -= overlap * nx;
          b1.y -= overlap * ny;
          b2.x += overlap * nx;
          b2.y += overlap * ny;
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
        painter: GamePainter(
          balls,
          deathZone,
          elasticZone,
          stretchLeft,
          stretchRight,
          stretchTop,
          stretchBottom,
        ),
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
  final double stretchLeft;
  final double stretchRight;
  final double stretchTop;
  final double stretchBottom;

  GamePainter(
    this.balls,
    this.deathZone,
    this.elasticZone,
    this.stretchLeft,
    this.stretchRight,
    this.stretchTop,
    this.stretchBottom,
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

    // Draw Elastic Zone with independent stretches for each side (denting effect)
    final elasticPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final path =
        Path()
          ..moveTo(elasticZone.left - stretchLeft, elasticZone.top - stretchTop)
          ..lineTo(
            elasticZone.right + stretchRight,
            elasticZone.top - stretchTop,
          )
          ..lineTo(
            elasticZone.right + stretchRight,
            elasticZone.bottom + stretchBottom,
          )
          ..lineTo(
            elasticZone.left - stretchLeft,
            elasticZone.bottom + stretchBottom,
          )
          ..close();
    canvas.drawPath(path, elasticPaint);

    // Draw balls
    for (var ball in balls) {
      final paint = Paint()..color = ball.color;
      canvas.drawCircle(Offset(ball.x, ball.y), ball.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
