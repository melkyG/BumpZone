import 'package:flutter/material.dart';
import '../models/player.dart';

class PlayerListHUD extends StatelessWidget {
  final List<Player> players;
  const PlayerListHUD({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.only(top: 8, right: 20, left: 20, bottom: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                // Black border (stroke)
                Text(
                  'Leaderboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2.5
                      ..color = Colors.black,
                  ),
                ),
                // White fill
                const Text(
                  'Leaderboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(minWidth: 150, minHeight: 100),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final player in players)
                    Text(
                      player.username,
                      style: const TextStyle(color: Color.fromARGB(255, 243, 243, 243), fontSize: 13, fontWeight: FontWeight.w300,),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
