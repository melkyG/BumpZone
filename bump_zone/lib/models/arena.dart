import 'dart:math';
import 'package:vector_math/vector_math_64.dart' show Vector2;
import '../models/ball.dart';
import 'physics_utils.dart';

class ElasticBand {
  final int numPts; // Number of nodes (including fixed posts)
  double springConstant; // Hooke's law spring constant
  double dampingCoeff; // Damping coefficient
  double mass; // Mass of each node
  double restLength; // Rest length of each spring
  List<Vector2> points; // Positions of nodes
  List<Vector2> velocities; // Velocities of nodes
  final List<int> fixedIndices; // Indices of fixed nodes (posts)
  double coefficientOfRestitution; // Collision elasticity

  ElasticBand({
    required this.numPts,
    required double sideLength,
    required Vector2 start,
    required Vector2 end,
    this.springConstant = 100.0,
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

  // Update parameters dynamically
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
      this.restLength = (restLength / 0.95) * restLengthScale; // Adjust based on original sideLength
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

  void handleBallCollision(Ball ball, double deltaT) {
    for (int i = 0; i < numPts - 1; i++) {
      if (fixedIndices.contains(i) && fixedIndices.contains(i + 1)) continue;
      if (PhysicsUtils.detectBallBandCollision(ball, points[i], points[i + 1], deltaT, 5.0)) {
        PhysicsUtils.resolveBallBandCollision(ball, this, i, coefficientOfRestitution);
      }
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

  // Update band parameters
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