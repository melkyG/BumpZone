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
                      ..strokeWidth = 2.2
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
                      style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 13, fontWeight: FontWeight.w100,),
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
  final int segmentsPerSide;
  final double restLengthScale;
  final ValueChanged<double> onSpringChanged;
  final ValueChanged<double> onDampingChanged;
  final ValueChanged<double> onMassChanged;
  final ValueChanged<double> onRestitutionChanged;
  final ValueChanged<int> onSegmentsChanged;
  final ValueChanged<double> onRestLengthScaleChanged;
  final VoidCallback onResetToDefault;
  final VoidCallback onRespawn;

  const BandSettingsHUD({
    super.key,
    required this.springConstant,
    required this.dampingCoeff,
    required this.mass,
    required this.restitution,
    required this.segmentsPerSide,
    required this.restLengthScale,
    required this.onSpringChanged,
    required this.onDampingChanged,
    required this.onMassChanged,
    required this.onRestitutionChanged,
    required this.onSegmentsChanged,
    required this.onRestLengthScaleChanged,
    required this.onResetToDefault,
    required this.onRespawn,
  });

  @override
  State<BandSettingsHUD> createState() => _BandSettingsHUDState();
}

class _BandSettingsHUDState extends State<BandSettingsHUD> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = false;
  }

  @override
  void didUpdateWidget(covariant BandSettingsHUD oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No local state for slider values! Always use widget.springConstant, etc.
    // If you previously had local state for slider values, REMOVE it.
  }

  @override
  Widget build(BuildContext context) {
    // Always use widget.springConstant, etc. directly from parent
    return Container(
      width: _expanded ? 350 : null,
      padding: _expanded ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                const SizedBox(width: 4),
                const Text('Band Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            _buildSlider(
              label: 'Spring Constant',
              value: widget.springConstant,
              min: 1.0,
              max: 300.0,
              divisions: 299,
              onChanged: widget.onSpringChanged,
            ),
            _buildSlider(
              label: 'Damping Coefficient',
              value: widget.dampingCoeff,
              min: 0.01,
              max: 5.0,
              divisions: 100,
              onChanged: widget.onDampingChanged,
            ),
            _buildSlider(
              label: 'Node Mass',
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Segments Per Side: ${widget.segmentsPerSide}', style: const TextStyle(fontSize: 16)),
                  Slider(
                    value: widget.segmentsPerSide.toDouble(),
                    min: 5,
                    max: 100,
                    divisions: 95,
                    label: widget.segmentsPerSide.toString(),
                    onChanged: (v) => widget.onSegmentsChanged(v.round()),
                  ),
                ],
              ),
            ),
            _buildSlider(
              label: 'Rest Length Scale',
              value: widget.restLengthScale,
              min: 0.01,
              max: 2.0,
              divisions: 199,
              onChanged: widget.onRestLengthScaleChanged,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: widget.onResetToDefault,
                  child: const Text('Default'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: widget.onRespawn,
                  child: const Text('Respawn'),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
          Slider(
            value: value.clamp(min, max), // Clamp to avoid errors if server sends out-of-range
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

class HUD extends StatelessWidget {
  final List<Player> players;
  final double springConstant;
  final double dampingCoeff;
  final double mass;
  final double restitution;
  final int segmentsPerSide;
  final double restLengthScale;
  final ValueChanged<double> onSpringChanged;
  final ValueChanged<double> onDampingChanged;
  final ValueChanged<double> onMassChanged;
  final ValueChanged<double> onRestitutionChanged;
  final ValueChanged<int> onSegmentsChanged;
  final ValueChanged<double> onRestLengthScaleChanged;
  final VoidCallback onResetToDefault;
  final VoidCallback onRespawn;

  final double? staminaPercent; // Add this

  const HUD({
    super.key,
    required this.players,
    required this.springConstant,
    required this.dampingCoeff,
    required this.mass,
    required this.restitution,
    required this.segmentsPerSide,
    required this.restLengthScale,
    required this.onSpringChanged,
    required this.onDampingChanged,
    required this.onMassChanged,
    required this.onRestitutionChanged,
    required this.onSegmentsChanged,
    required this.onRestLengthScaleChanged,
    required this.onResetToDefault,
    required this.onRespawn,
    this.staminaPercent,
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
            segmentsPerSide: segmentsPerSide,
            restLengthScale: restLengthScale,
            onSpringChanged: onSpringChanged,
            onDampingChanged: onDampingChanged,
            onMassChanged: onMassChanged,
            onRestitutionChanged: onRestitutionChanged,
            onSegmentsChanged: onSegmentsChanged,
            onRestLengthScaleChanged: onRestLengthScaleChanged,
            onResetToDefault: onResetToDefault,
            onRespawn: onRespawn,
          ),
        ),
        // --- Battery/Stamina HUD in bottom right ---
        Positioned(
          right: 20, // Reduced margin from 24 to 8
          bottom: 20, // Reduced margin from 24 to 8
          child: Opacity(
            opacity: 0.85, // Set transparency (0.0 = fully transparent, 1.0 = opaque)
            child: _BatteryWidget(staminaPercent: staminaPercent ?? 1.0),
          ),
        ),
      ],
    );
  }
}

// Add this widget for the battery
class _BatteryWidget extends StatelessWidget {
  final double staminaPercent;
  const _BatteryWidget({required this.staminaPercent});

  @override
  Widget build(BuildContext context) {
    const double width = 350;
    const double height = 50;
    const double border = 7;
    const double tipWidth = 8;
    const double tipHeight = 17;
    final double fillWidth = (width - border * 2) * staminaPercent.clamp(0.0, 1.0);

    return SizedBox(
      width: width + tipWidth + 4,
      height: height,
      child: Stack(
        children: [
          // Battery body
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: border),
                borderRadius: BorderRadius.circular(6),
                color: Colors.transparent,
              ),
            ),
          ),
          // Battery tip
          Positioned(
            left: width,
            top: (height - tipHeight) / 2,
            child: Container(
              width: tipWidth,
              height: tipHeight,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Battery fill
          Positioned(
            left: border,
            top: border,
            child: Container(
              width: fillWidth,
              height: height - border * 2,
              decoration: BoxDecoration(
                color: staminaPercent > 0.2
                    ? Colors.green
                    : (staminaPercent > 0.05 ? Colors.orange : Colors.red),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
