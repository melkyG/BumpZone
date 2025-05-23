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
      id: json['id'] as String,
      username: json['username'] as String,
      positionX: (json['position']['x'] as num).toDouble(),
      positionY: (json['position']['y'] as num).toDouble(),
      velocityX: (json['velocity']['x'] as num).toDouble(),
      velocityY: (json['velocity']['y'] as num).toDouble(),
    );
  }
}