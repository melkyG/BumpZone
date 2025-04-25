import 'package:flutter/material.dart';
import 'package:flame/game.dart';

void main() {
  runApp(GameWidget(game: PhysicsGame()));
}

class PhysicsGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    // Game setup will go here
  }
}