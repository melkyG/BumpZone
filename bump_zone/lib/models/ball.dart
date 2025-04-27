import 'package:vector_math/vector_math_64.dart' show Vector2;

class Ball {
  Vector2 position;
  Vector2 velocity;
  final double mass;
  final double radius;

  Ball({
    required this.position,
    required this.velocity,
    this.mass = 1.0,
    this.radius = 10.0,
  });

  void update(double deltaT) {
    position += velocity * deltaT;
  }
}