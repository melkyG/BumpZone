import 'package:flutter/material.dart';
import 'ball.dart';

class DeathZone {
  Rect boundary; // The outer rectangle
  double threshold; // How close the ball can get before dying

  DeathZone({
    required this.boundary,
    this.threshold = 5.0,
  });

  // Check if the ball is too close to the death zone
  bool checkCollision(Ball ball) {
    double leftDist = (ball.position.dx - ball.size - boundary.left).abs();
    double rightDist = (ball.position.dx + ball.size - boundary.right).abs();
    double topDist = (ball.position.dy - ball.size - boundary.top).abs();
    double bottomDist = (ball.position.dy + ball.size - boundary.bottom).abs();

    // If the ball is too close to any edge, it dies
    if (leftDist < threshold ||
        rightDist < threshold ||
        topDist < threshold ||
        bottomDist < threshold) {
      ball.isAlive = false;
      return true;
    }
    return false;
  }
}