class Player {
  final String id;
  final String username;
  final String? color;
  final double? mass;

  Player({
    required this.id,
    required this.username,
    this.color,
    this.mass,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      color: json['color'] as String?,
      mass: json['mass'] != null ? (json['mass'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (color != null) 'color': color,
      if (mass != null) 'mass': mass,
    };
  }
}