import 'dart:math';
import 'package:vector_math/vector_math_64.dart' show Vector2;
import '../models/ball.dart';
import 'physics_utils.dart';

class ElasticBand {
  final int numPts;
  double springConstant;
  double dampingCoeff;
  double mass;
  double restLength;
  List<Vector2> points;
  List<Vector2> velocities;
  final List<int> fixedIndices;
  double coefficientOfRestitution;

  ElasticBand({
    required this.numPts,
    required double sideLength,
    required Vector2 start,
    required Vector2 end,
    this.springConstant = 75.0,
    this.dampingCoeff = 0.0,
    this.mass = 0.1,
    double restLengthScale = 0.95,
    this.coefficientOfRestitution = 1.0,
  })  : restLength = (sideLength / (numPts - 1)) * restLengthScale,
        points = [],
        velocities = [],
        fixedIndices = [0, numPts - 1] {
    _setInitialState(start, end);
  }

  void _setInitialState(Vector2 start, Vector2 end) {
    points = List.generate(numPts, (i) {
      final t = i / (numPts - 1);
      return start + (end - start) * t;
    });

    for (int i = 1; i < numPts - 1; i++) {
      final offset = Vector2(
        15.0 * sin(i * pi / (numPts - 1)),
        15.0 * cos(i * pi / (numPts - 1)),
      );
      points[i] += offset;
    }

    velocities = List.generate(numPts, (_) => Vector2.zero());
  }

  void updateParameters({
    double? springConstant,
    double? dampingCoeff,
    double? mass,
    double? restLengthScale,
    double? coefficientOfRestitution,
  }) {
    if (springConstant != null && springConstant > 0) {
      this.springConstant = springConstant;
    }
    if (dampingCoeff != null && dampingCoeff >= 0) {
      this.dampingCoeff = dampingCoeff;
    }
    if (mass != null && mass > 0) {
      this.mass = mass;
    }
    if (restLengthScale != null && restLengthScale > 0) {
      this.restLength = (restLength / 0.95) * restLengthScale;
    }
    if (coefficientOfRestitution != null && coefficientOfRestitution >= 0) {
      this.coefficientOfRestitution = coefficientOfRestitution;
    }
  }

  List<Vector2> _computeHookeForces() {
    final forces = List.generate(numPts, (_) => Vector2.zero());
    for (int i = 0; i < numPts; i++) {
      if (fixedIndices.contains(i)) continue;

      if (i > 0) {
        final prevPt = points[i - 1];
        final currPt = points[i];
        final direction = prevPt - currPt;
        final length = direction.length;
        if (length == 0) continue;
        final forceMag = springConstant * (length - restLength);
        forces[i] += direction.normalized() * forceMag;
      }

      if (i < numPts - 1) {
        final nextPt = points[i + 1];
        final currPt = points[i];
        final direction = nextPt - currPt;
        final length = direction.length;
        if (length == 0) continue;
        final forceMag = springConstant * (length - restLength);
        forces[i] += direction.normalized() * forceMag;
      }
    }
    return forces;
  }

  void updateState(double deltaT) {
    final hookeForces = _computeHookeForces();
    for (int i = 0; i < numPts; i++) {
      if (fixedIndices.contains(i)) continue;

      final dampingForce = velocities[i] * (-dampingCoeff);
      final totalForce = hookeForces[i] + dampingForce;
      final acceleration = totalForce / mass;
      velocities[i] += acceleration * deltaT;
      points[i] += velocities[i] * deltaT;
    }
  }

  void _enforceNoSeepIntoBall(Ball ball) {
    for (int i = 0; i < points.length; i++) {
      if (fixedIndices.contains(i)) continue;

      final toPoint = points[i] - ball.position;
      final distance = toPoint.length;

      if (distance < ball.radius) {
        final correction = toPoint.normalized() * (ball.radius - distance);
        points[i] += correction;
        velocities[i] += correction * 5.0;
      }
    }
  }

  void handleBallCollision(Ball ball, double deltaT) {
    double minDistance = double.infinity;
    int? closestSegmentIndex;
    Vector2? closestPoint;

    for (int i = 0; i < numPts - 1; i++) {
      if (fixedIndices.contains(i) && fixedIndices.contains(i + 1)) continue;

      final p1 = points[i];
      final p2 = points[i + 1];

      if (PhysicsUtils.detectBallBandCollision(ball, p1, p2, deltaT, 5.0)) {
        final segment = p2 - p1;
        final t = ((ball.position - p1).dot(segment) / segment.dot(segment)).clamp(0.0, 1.0);
        final point = p1 + segment * t;
        final distance = (ball.position - point).length;
        if (distance < minDistance) {
          minDistance = distance;
          closestSegmentIndex = i;
          closestPoint = point;
        }
      }
    }

    _enforceNoSeepIntoBall(ball);

    if (closestSegmentIndex != null && closestPoint != null) {
      PhysicsUtils.resolveBallBandCollision(ball, this, closestSegmentIndex, coefficientOfRestitution);
    }
  }
}

class Arena {
  final List<ElasticBand> bands;
  final List<Vector2> posts;
  final double sideLength;
  final int numPtsPerSide;

  Arena({
    required this.sideLength,
    required this.numPtsPerSide,
    required Vector2 topLeft,
  }) : bands = [], posts = [] {
    posts.addAll([
      topLeft,
      Vector2(topLeft.x + sideLength, topLeft.y),
      Vector2(topLeft.x + sideLength, topLeft.y + sideLength),
      Vector2(topLeft.x, topLeft.y + sideLength),
    ]);

    bands.addAll([
      ElasticBand(
        numPts: numPtsPerSide,
        sideLength: sideLength,
        start: posts[0],
        end: posts[1],
      ),
      ElasticBand(
        numPts: numPtsPerSide,
        sideLength: sideLength,
        start: posts[1],
        end: posts[2],
      ),
      ElasticBand(
        numPts: numPtsPerSide,
        sideLength: sideLength,
        start: posts[2],
        end: posts[3],
      ),
      ElasticBand(
        numPts: numPtsPerSide,
        sideLength: sideLength,
        start: posts[3],
        end: posts[0],
      ),
    ]);
  }

  void updateBandParameters({
    double? springConstant,
    double? dampingCoeff,
    double? mass,
    double? restLengthScale,
    double? coefficientOfRestitution,
  }) {
    for (var band in bands) {
      band.updateParameters(
        springConstant: springConstant,
        dampingCoeff: dampingCoeff,
        mass: mass,
        restLengthScale: restLengthScale,
        coefficientOfRestitution: coefficientOfRestitution,
      );
    }
  }

  void update(double deltaT, Ball? ball) {
    for (var band in bands) {
      band.updateState(deltaT);
      if (ball != null) {
        band.handleBallCollision(ball, deltaT);
      }
    }
  }
}
