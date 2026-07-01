class AuthProfile {
  const AuthProfile({
    required this.name,
    required this.username,
    required this.secret,
  });

  final String name;
  final String username;
  final String secret;

  String get label => '$name ($username)';

  Map<String, dynamic> toJson() => {
        'name': name,
        'username': username,
        'secret': secret,
      };

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    return AuthProfile(
      name: json['name']?.toString() ?? 'Profil',
      username: json['username']?.toString() ?? '',
      secret: json['secret']?.toString() ?? '',
    );
  }
}
