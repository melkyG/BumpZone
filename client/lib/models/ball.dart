// Ball model for multiplayer game
class Ball {
  final String id;
  final double x;
  final double y;
  final double vx;
  final double vy;
  final String? color;
  final double? stamina; // Add this field

  Ball({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.color,
    this.stamina, // Add this
  });

  factory Ball.fromJson(Map<String, dynamic> json) {
    return Ball(
      id: json['id'].toString(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      vx: (json['vx'] as num).toDouble(),
      vy: (json['vy'] as num).toDouble(),
      color: json['color'] as String?,
      stamina: json['stamina'] != null ? (json['stamina'] as num).toDouble() : null, // Add this
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'vx': vx,
        'vy': vy,
        if (color != null) 'color': color, // Include color if present
        if (stamina != null) 'stamina': stamina, // Include stamina if present
      };
}
