import 'package:flutter/material.dart';
import 'package:bump_zone/widgets/game_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: const GameWidget(),
      ),
    );
  }
}