class Player {
  final String id;
  final String username;
  final String? color;

  Player({
    required this.id,
    required this.username,
    this.color,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (color != null) 'color': color,
    };
  }
}