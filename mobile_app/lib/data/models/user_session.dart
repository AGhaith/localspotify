class UserSession {
  final String serverUrl;
  final String username;
  final String token;
  final String salt;
  final String clientName;

  const UserSession({
    required this.serverUrl,
    required this.username,
    required this.token,
    required this.salt,
    this.clientName = 'LocalSpotify-Flutter',
  });

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'token': token,
        'salt': salt,
        'clientName': clientName,
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        serverUrl: json['serverUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        token: json['token'] as String? ?? '',
        salt: json['salt'] as String? ?? '',
        clientName: json['clientName'] as String? ?? 'LocalSpotify-Flutter',
      );

  Map<String, String> get authQueryParams => {
        'u': username,
        't': token,
        's': salt,
        'v': '1.16.1',
        'c': clientName,
        'f': 'json',
      };
}
