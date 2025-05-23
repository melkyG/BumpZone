class Player {
  final String id;
  final String username;
  final double positionX;
  final double positionY;
  final double velocityX;
  final double velocityY;

  Player({
    required this.id,
    required this.username,
    required this.positionX,
    required this.positionY,
    required this.velocityX,
    required this.velocityY,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      positionX: (json['x'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['y'] as num?)?.toDouble() ?? 0.0,
      velocityX: (json['velocityX'] as num?)?.toDouble() ?? 0.0,
      velocityY: (json['velocityY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'x': positionX,
      'y': positionY,
      'velocityX': velocityX,
      'velocityY': velocityY,
    };
  }
}