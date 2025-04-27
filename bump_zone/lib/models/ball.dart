import 'package:vector_math/vector_math_64.dart' show Vector2;

class Ball {
  Vector2 position;
  Vector2 velocity;
  final double mass;
  final double radius;
  Vector2 force; // External force (e.g., from cursor)
  int collisionCooldown = 0;

  Ball({
    required this.position,
    required this.velocity,
    required this.mass,
    required this.radius,
  }) : force = Vector2.zero();


  void update(double deltaT) {
    if (collisionCooldown > 0) collisionCooldown--;
    // Apply external force
    final acceleration = force / mass;
    velocity += acceleration * deltaT;
    position += velocity * deltaT;
    // Reset force after applying (force is re-applied each frame if active)
    force = Vector2.zero();
  }
}