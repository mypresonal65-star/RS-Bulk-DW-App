class UserPermissions {
  final bool allowHeaders;
  final bool allowTxt;
  final bool allowBat;

  UserPermissions({
    this.allowHeaders = false,
    this.allowTxt = false,
    this.allowBat = false,
  });

  factory UserPermissions.fromJson(Map<String, dynamic> json) {
    return UserPermissions(
      allowHeaders: json['allow_headers'] == true || json['allow_headers'] == 1,
      allowTxt: json['allow_txt'] == true || json['allow_txt'] == 1,
      allowBat: json['allow_bat'] == true || json['allow_bat'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'allow_headers': allowHeaders,
    'allow_txt': allowTxt,
    'allow_bat': allowBat,
  };
}

class UserSession {
  final String token;
  final String hwid;
  final String userName;
  final String keyCode;
  final int expiresAt;
  final int remainingSeconds;
  final String remainingFormatted;
  final UserPermissions permissions;

  UserSession({
    required this.token,
    required this.hwid,
    required this.userName,
    required this.keyCode,
    required this.expiresAt,
    required this.remainingSeconds,
    required this.remainingFormatted,
    required this.permissions,
  });

  bool get isExpired => expiresAt > 0 && expiresAt < (DateTime.now().millisecondsSinceEpoch ~/ 1000);

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      token: json['token'] ?? '',
      hwid: json['hwid'] ?? '',
      userName: json['user_name'] ?? 'User',
      keyCode: json['key_code'] ?? '',
      expiresAt: json['expires_at'] ?? 0,
      remainingSeconds: json['remaining_seconds'] ?? 0,
      remainingFormatted: json['remaining_formatted'] ?? '',
      permissions: UserPermissions.fromJson(json['permissions'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'hwid': hwid,
    'user_name': userName,
    'key_code': keyCode,
    'expires_at': expiresAt,
    'remaining_seconds': remainingSeconds,
    'remaining_formatted': remainingFormatted,
    'permissions': permissions.toJson(),
  };
}
