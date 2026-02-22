class Account {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String cookiePath;

  Account({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.cookiePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'cookiePath': cookiePath,
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String,
      cookiePath: json['cookiePath'] as String,
    );
  }

  Account copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? cookiePath,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      cookiePath: cookiePath ?? this.cookiePath,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
