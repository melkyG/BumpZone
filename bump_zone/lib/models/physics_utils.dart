import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'ball.dart';
import 'arena.dart';

class PhysicsUtils {
  static bool detectBallBandCollision(
    Ball ball,
    Vector2 p1,
    Vector2 p2,
    double deltaT,
    double buffer,
  ) {
    if (ball.collisionCooldown > 0) return false; // Added cooldown check

    final segment = p2 - p1;
    final ballStart = ball.position - ball.velocity * deltaT;
    final ballEnd = ball.position;

    final segmentDot = segment.dot(segment);
    if (segmentDot == 0) return false;
    final t = ((ballStart - p1).dot(segment)) / segmentDot;
    final closestT = t.clamp(0.0, 1.0);
    final closestPoint = p1 + segment * closestT;

    final d = _distanceToSegment(ballStart, ballEnd, closestPoint);
    final currentDistance = (ball.position - closestPoint).length;

    //print('Band detection: d=$d, currentDistance=$currentDistance, radius+buffer=${ball.radius + buffer}');
    return d <= ball.radius + buffer && currentDistance <= ball.radius + buffer; // Added currentDistance check
  }

  static bool detectBallPostCollision(
    Ball ball,
    Vector2 post,
    double deltaT,
    double buffer,
  ) {
    if (ball.collisionCooldown > 0) return false; // Added cooldown check

    final ballStart = ball.position - ball.velocity * deltaT;
    final ballEnd = ball.position;

    final d = _distanceToSegment(ballStart, ballEnd, post);
    final currentDistance = (ball.position - post).length;

    //print('Post detection: post=$post, d=$d, currentDistance=$currentDistance, radius+buffer=${ball.radius + buffer}');
    return d <= ball.radius + buffer || currentDistance <= ball.radius + buffer; // Added currentDistance check
  }

  static void resolveBallBandCollision(
    Ball ball,
    ElasticBand band,
    int segmentIndex,
    double coefficientOfRestitution,
  ) {
    if (ball.collisionCooldown > 0) return; // Added cooldown check

    final p1 = band.points[segmentIndex];
    final p2 = band.points[segmentIndex + 1];
    final segment = p2 - p1;

    final normal = Vector2(-segment.y, segment.x).normalized();
    final toBall = ball.position - (p1 + p2) / 2;
    if (normal.dot(toBall) < 0) {
      normal.scale(-1);
    }

    // Position correction
    final closestPoint = p1 + segment * (((ball.position - p1).dot(segment) / segment.dot(segment)).clamp(0.0, 1.0));
    final distance = (ball.position - closestPoint).length;
    if (distance < ball.radius) {
      final correction = (ball.radius - distance) * 1.05;
      ball.position += normal * correction;
    }

    final v1 = ball.velocity;
    final v2 = (band.velocities[segmentIndex] + band.velocities[segmentIndex + 1]) / 2;
    final relativeVelocity = v1 - v2;

    // Skip micro-collisions
    if (relativeVelocity.dot(normal).abs() < 0.5) {
      //print('Skipped band collision: micro-collision, relativeVelocity.dot(normal)=${relativeVelocity.dot(normal)}');
      return;
    }

    final impulseMagnitude = -(1 + coefficientOfRestitution) * relativeVelocity.dot(normal) /
        (1 / ball.mass + 1 / (2 * band.mass));

    ball.velocity += normal * (impulseMagnitude / ball.mass);
    band.velocities[segmentIndex] -= normal * (impulseMagnitude / (2 * band.mass));
    band.velocities[segmentIndex + 1] -= normal * (impulseMagnitude / (2 * band.mass));

    ball.collisionCooldown = 0; // Added cooldown

    //print('Band collision: segment=$segmentIndex, ball.pos=${ball.position}, ball.vel=${ball.velocity}, normal=$normal, impulse=$impulseMagnitude');
  }

  static void resolveBallPostCollision(
    Ball ball,
    Vector2 post,
    double coefficientOfRestitution,
  ) {
    // Normal points from post to ball
    final toBall = ball.position - post;
    final distance = toBall.length;
    if (distance == 0) {
      //print('Warning: Ball at post position, skipping collision');
      return; // Avoid division by zero
    }
    final normal = toBall.normalized();

    // Position correction
    if (distance < ball.radius) {
      final correction = (ball.radius - distance) * 1.05;
      ball.position += normal * correction;
    }

    // Relative velocity (post is fixed)
    final relativeVelocity = ball.velocity;

   

    // Impulse (post has infinite mass)
    final impulseMagnitude = -(1 + 0.5) * relativeVelocity.dot(normal) / (1 / ball.mass);

    // Apply impulse to ball
    ball.velocity += normal * (impulseMagnitude / ball.mass);

    ball.collisionCooldown = 3; // Added cooldown

    //print('Post collision: post=$post, ball.pos=${ball.position}, ball.vel=${ball.velocity}, normal=$normal, impulse=$impulseMagnitude');
  }

  static double _distanceToSegment(Vector2 start, Vector2 end, Vector2 point) {
    final segment = end - start;
    final segmentLengthSquared = segment.dot(segment);
    if (segmentLengthSquared == 0) return (point - start).length;

    final t = ((point - start).dot(segment) / segmentLengthSquared).clamp(0.0, 1.0);
    final projection = start + segment * t;
    return (point - projection).length;
  }
}