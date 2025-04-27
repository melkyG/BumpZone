import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'ball.dart';
import 'arena.dart';

class PhysicsUtils {
  // Detects if a ball collides with a band segment (between nodes i and i+1)
  static bool detectBallBandCollision(
    Ball ball,
    Vector2 p1,
    Vector2 p2,
    double deltaT,
    double buffer,
  ) {
    // Line segment from p1 to p2
    final segment = p2 - p1;
    final ballStart = ball.position - ball.velocity * deltaT;
    final ballEnd = ball.position;

    // Find closest point on segment to ball's path
    final segmentDot = segment.dot(segment);
    if (segmentDot == 0) return false; // Avoid division by zero
    final t = ((ballStart - p1).dot(segment)) / segmentDot;
    final closestT = t.clamp(0.0, 1.0);
    final closestPoint = p1 + segment * closestT;

    // Check if ball's path intersects segment within radius + buffer
    final d = _distanceToSegment(ballStart, ballEnd, closestPoint);
    return d <= ball.radius + buffer;
  }

  // Resolves collision by applying impulses to ball and band nodes
  static void resolveBallBandCollision(
    Ball ball,
    ElasticBand band,
    int segmentIndex,
    double coefficientOfRestitution,
  ) {
    final p1 = band.points[segmentIndex];
    final p2 = band.points[segmentIndex + 1];
    final segment = p2 - p1;

    // Normal vector (perpendicular to segment)
    final normal = Vector2(-segment.y, segment.x).normalized();
    

    // Ensure normal points away from ball
    final toBall = ball.position - (p1 + p2) / 2;
    if (normal.dot(toBall) < 0) {
      normal.scale(-1);
    }
    // Position correction to prevent sticking
    final closestPoint = p1 + segment * (((ball.position - p1).dot(segment) / segment.dot(segment)).clamp(0.0, 1.0));
    final distance = (ball.position - closestPoint).length;
    if (distance < ball.radius) {
      final correction = (ball.radius - distance) * 1.01; // Slight over-correction
      ball.position += normal * correction;
    }

    // Relative velocity
    final v1 = ball.velocity;
    final v2 = (band.velocities[segmentIndex] + band.velocities[segmentIndex + 1]) / 2;
    final relativeVelocity = v1 - v2;
    if (relativeVelocity.dot(normal).abs() < 0.1) return;

    // Impulse along normal
    final impulseMagnitude = -(1 + coefficientOfRestitution) * relativeVelocity.dot(normal) /
        (1 / ball.mass + 1 / (2 * band.mass));

    // Apply impulses
    ball.velocity += normal * (impulseMagnitude / ball.mass);
    band.velocities[segmentIndex] -= normal * (impulseMagnitude / (2 * band.mass));
    band.velocities[segmentIndex + 1] -= normal * (impulseMagnitude / (2 * band.mass));
  }

  // Helper: Distance from a point to a line segment
  static double _distanceToSegment(Vector2 start, Vector2 end, Vector2 point) {
    final segment = end - start;
    final segmentLengthSquared = segment.dot(segment);
    if (segmentLengthSquared == 0) return (point - start).length;

    final t = ((point - start).dot(segment) / segmentLengthSquared).clamp(0.0, 1.0);
    final projection = start + segment * t;
    return (point - projection).length;
  }
}