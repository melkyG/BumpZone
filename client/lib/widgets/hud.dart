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

class BandSettingsHUD extends StatelessWidget {
  final double springConstant;
  final double dampingCoeff;
  final double mass;
  final double restitution;
  final ValueChanged<double> onSpringChanged;
  final ValueChanged<double> onDampingChanged;
  final ValueChanged<double> onMassChanged;
  final ValueChanged<double> onRestitutionChanged;

  const BandSettingsHUD({
    super.key,
    required this.springConstant,
    required this.dampingCoeff,
    required this.mass,
    required this.restitution,
    required this.onSpringChanged,
    required this.onDampingChanged,
    required this.onMassChanged,
    required this.onRestitutionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(12),
      color: Colors.white.withOpacity(0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Band Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          _buildSlider(
            label: 'Spring Constant',
            value: springConstant,
            min: 1.0,
            max: 100.0,
            divisions: 99,
            onChanged: onSpringChanged,
          ),
          _buildSlider(
            label: 'Damping Coefficient',
            value: dampingCoeff,
            min: 0.01,
            max: 5.0,
            divisions: 100,
            onChanged: onDampingChanged,
          ),
          _buildSlider(
            label: 'Node Mass',
            value: mass,
            min: 0.01,
            max: 5.0,
            divisions: 100,
            onChanged: onMassChanged,
          ),
          _buildSlider(
            label: 'Restitution',
            value: restitution,
            min: 0.01,
            max: 1.0,
            divisions: 100,
            onChanged: onRestitutionChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15)),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
