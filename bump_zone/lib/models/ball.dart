import 'package:vector_math/vector_math_64.dart' show Vector2;

class Ball {
  Vector2 position;
  Vector2 velocity;
  final double mass;
  final double radius;
  Vector2 force;
  int collisionCooldown;

  Ball({
    required this.position,
    required this.velocity,
    required this.mass,
    required this.radius,
  })  : force = Vector2.zero(),
        collisionCooldown = 0;

  void update(double deltaT) {
    if (collisionCooldown > 0) collisionCooldown--;
    final acceleration = force / mass;
    velocity += acceleration * deltaT;
    position += velocity * deltaT;
    force = Vector2.zero();
  }
}