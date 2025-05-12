import 'package:flutter/material.dart';
import '../game/arena.dart';
import '../game/ball.dart';

class GamePainter extends CustomPainter {
  final Arena arena;
  final Ball ball;
  final String username;

  GamePainter({
    required this.arena,
    required this.ball,
    required this.username,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final postPaint = Paint()..color = const Color.fromARGB(255, 0, 0, 0);
    //..style = PaintingStyle.fill;
    final bandPaint =
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    final ballPaint =
        Paint()
          ..color = const Color.fromARGB(255, 27, 63, 28)
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
    canvas.drawCircle(
      Offset(ball.position.x, ball.position.y),
      ball.radius,
      ballPaint,
    );

    // Draw username below the ball
    final textSpan = TextSpan(
      text: username,
      style: TextStyle(color: Colors.black, fontSize: 14),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final offset = Offset(
      ball.position.x - textPainter.width / 2,
      ball.position.y + ball.radius + 4,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
