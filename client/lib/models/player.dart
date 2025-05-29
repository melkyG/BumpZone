
class Player {
  final String id;
  final String username;


  Player({
    required this.id,
    required this.username,

  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',

    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }
}