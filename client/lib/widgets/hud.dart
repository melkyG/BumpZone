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

class BandSettingsHUD extends StatefulWidget {
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
  State<BandSettingsHUD> createState() => _BandSettingsHUDState();
}

class _BandSettingsHUDState extends State<BandSettingsHUD> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(top: 12, left: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(_expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                const SizedBox(width: 4),
                const Text('Band Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          if (_expanded)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildSlider(
                  label: 'Spring',
                  value: widget.springConstant,
                  min: 1.0,
                  max: 100.0,
                  divisions: 99,
                  onChanged: widget.onSpringChanged,
                ),
                _buildSlider(
                  label: 'Damping',
                  value: widget.dampingCoeff,
                  min: 0.01,
                  max: 5.0,
                  divisions: 100,
                  onChanged: widget.onDampingChanged,
                ),
                _buildSlider(
                  label: 'Mass',
                  value: widget.mass,
                  min: 0.01,
                  max: 5.0,
                  divisions: 100,
                  onChanged: widget.onMassChanged,
                ),
                _buildSlider(
                  label: 'Restitution',
                  value: widget.restitution,
                  min: 0.01,
                  max: 1.0,
                  divisions: 100,
                  onChanged: widget.onRestitutionChanged,
                ),
              ],
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label: ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class HUD extends StatelessWidget {
  final List<Player> players;
  final double springConstant;
  final double dampingCoeff;
  final double mass;
  final double restitution;
  final ValueChanged<double> onSpringChanged;
  final ValueChanged<double> onDampingChanged;
  final ValueChanged<double> onMassChanged;
  final ValueChanged<double> onRestitutionChanged;

  const HUD({
    super.key,
    required this.players,
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
    return Stack(
      children: [
        PlayerListHUD(players: players),
        Align(
          alignment: Alignment.topLeft,
          child: BandSettingsHUD(
            springConstant: springConstant,
            dampingCoeff: dampingCoeff,
            mass: mass,
            restitution: restitution,
            onSpringChanged: onSpringChanged,
            onDampingChanged: onDampingChanged,
            onMassChanged: onMassChanged,
            onRestitutionChanged: onRestitutionChanged,
          ),
        ),
      ],
    );
  }
}
