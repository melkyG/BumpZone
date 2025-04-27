import 'package:flutter/material.dart';
import '../models/arena.dart';
import '../models/ball.dart';

class GamePainter extends CustomPainter {
  final Arena arena;
  final Ball ball;

  GamePainter({required this.arena, required this.ball});

  @override
  void paint(Canvas canvas, Size size) {
    final postPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final bandPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final ballPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    // Draw each band
    for (var band in arena.bands) {
      final path = Path();
      path.moveTo(band.points[0].x, band.points[0].y);
      for (int i = 1; i < band.points.length; i++) {
        path.lineTo(band.points[i].x, band.points[i].y);
      }
      canvas.drawPath(path, bandPaint);
    }

    // Draw posts
    for (var post in arena.posts) {
      canvas.drawCircle(Offset(post.x, post.y), 5.0, postPaint);
    }

    // Draw ball
    canvas.drawCircle(Offset(ball.position.x, ball.position.y), ball.radius, ballPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}