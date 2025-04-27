import 'dart:math';
import 'package:vector_math/vector_math_64.dart' show Vector2;
import '../models/ball.dart';
import 'physics_utils.dart';

class ElasticBand {
  final int numPts; // Number of nodes (including fixed posts)
  final double springConstant; // Hooke's law spring constant
  final double dampingCoeff; // Damping coefficient
  final double mass; // Mass of each node
  final double restLength; // Rest length of each spring
  List<Vector2> points; // Positions of nodes
  List<Vector2> velocities; // Velocities of nodes
  final List<int> fixedIndices; // Indices of fixed nodes (posts)

  ElasticBand({
    required this.numPts,
    required double sideLength,
    required Vector2 start,
    required Vector2 end,
    this.springConstant = 1.0,
    this.dampingCoeff = 0.1,
    this.mass = 1.0,
  })  : restLength = sideLength / (numPts - 1),
        points = [],
        velocities = [],
        fixedIndices = [0, numPts - 1] {
    _setInitialState(start, end);
  }

  void _setInitialState(Vector2 start, Vector2 end) {
    // Place nodes linearly between start and end
    points = List.generate(numPts, (i) {
      final t = i / (numPts - 1);
      return start + (end - start) * t;
    });
    // Perturb interior nodes to show oscillation
    for (int i = 1; i < numPts - 1; i++) {
      final offset = Vector2(
        10.0 * sin(i * pi / (numPts - 1)),
        10.0 * cos(i * pi / (numPts - 1)),
      );
      points[i] += offset;
    }
    velocities = List.generate(numPts, (_) => Vector2.zero());
  }

  List<Vector2> _computeHookeForces() {
    final forces = List.generate(numPts, (_) => Vector2.zero());
    for (int i = 0; i < numPts; i++) {
      if (fixedIndices.contains(i)) continue; // Skip fixed nodes
      // Spring to previous node
      if (i > 0) {
        final prevPt = points[i - 1];
        final currPt = points[i];
        final direction = prevPt - currPt;
        final length = direction.length;
        if (length == 0) continue;
        final forceMag = springConstant * (length - restLength);
        forces[i] += direction.normalized() * forceMag;
      }
      // Spring to next node
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
      if (fixedIndices.contains(i)) continue; // Skip fixed nodes
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
      if (PhysicsUtils.detectBallBandCollision(ball, points[i], points[i + 1], deltaT, 2.0)) {
        PhysicsUtils.resolveBallBandCollision(ball, this, i, 0.8);
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
    // Define the four posts
    posts.addAll([
      topLeft, // Top-left
      Vector2(topLeft.x + sideLength, topLeft.y), // Top-right
      Vector2(topLeft.x + sideLength, topLeft.y + sideLength), // Bottom-right
      Vector2(topLeft.x, topLeft.y + sideLength), // Bottom-left
    ]);

    // Create four bands connecting the posts
    bands.addAll([
      ElasticBand(
        numPts: numPtsPerSide,
        sideLength: sideLength,
        start: posts[0],
        end: posts[1],
      ), // Top
      ElasticBand(
        numPts: numPtsPerSide,
        sideLength: sideLength,
        start: posts[1],
        end: posts[2],
      ), // Right
      ElasticBand(
        numPts: numPtsPerSide,
        sideLength: sideLength,
        start: posts[2],
        end: posts[3],
      ), // Bottom
      ElasticBand(
        numPts: numPtsPerSide,
        sideLength: sideLength,
        start: posts[3],
        end: posts[0],
      ), // Left
    ]);
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