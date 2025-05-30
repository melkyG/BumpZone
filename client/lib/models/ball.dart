// Ball model for multiplayer game
class Ball {
  final String id;
  double x;
  double y;
  double vx;
  double vy;

  Ball({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  factory Ball.fromJson(Map<String, dynamic> json) {
    return Ball(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      vx: (json['vx'] as num).toDouble(),
      vy: (json['vy'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'vx': vx,
        'vy': vy,
      };
}
