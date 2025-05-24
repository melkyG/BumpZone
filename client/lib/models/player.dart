import 'package:vector_math/vector_math_64.dart' show Vector2;

class Player {
  final String id;
  final String username;
  Vector2 position;
  Vector2 velocity;
  final double mass;
  final double radius;
  Vector2 force;
  int collisionCooldown;

  Player({
    required this.id,
    required this.username,
    required this.position,
    required this.velocity,
    required this.mass,
    required this.radius,
  }) : force = Vector2.zero(),
       collisionCooldown = 0;

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      position: Vector2(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
      ),
      velocity: Vector2(
        (json['velocityX'] as num?)?.toDouble() ?? 0.0,
        (json['velocityY'] as num?)?.toDouble() ?? 0.0,
      ),
      mass: (json['mass'] as num?)?.toDouble() ?? 1.0,
      radius: (json['radius'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'x': position.x,
      'y': position.y,
      'velocityX': velocity.x,
      'velocityY': velocity.y,
      'mass': mass,
      'radius': radius,
    };
  }

  void update(double deltaT) {
    if (collisionCooldown > 0) collisionCooldown--;
    final acceleration = force / mass;
    velocity += acceleration * deltaT;
    position += velocity * deltaT;
    force = Vector2.zero();
  }
}
