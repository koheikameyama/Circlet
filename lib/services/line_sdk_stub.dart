// Stub implementation for Web platform (flutter_line_sdk is not supported on web)

class LineSDK {
  static final LineSDK instance = LineSDK._();

  LineSDK._();

  Future<void> setup(String channelId) async {
    // Do nothing on web
  }

  Future<void> logout() async {
    // Do nothing on web
  }

  Future<LoginResult> login({List<String>? scopes}) async {
    throw UnsupportedError('LINE SDK is not supported on web platform. Please use LineLoginWeb instead.');
  }
}

class LoginResult {
  final AccessToken accessToken;
  final UserProfile? userProfile;

  LoginResult({required this.accessToken, this.userProfile});
}

class AccessToken {
  final String value;

  AccessToken({required this.value});
}

class UserProfile {
  final String userId;
  final String displayName;
  final String? pictureUrl;

  UserProfile({
    required this.userId,
    required this.displayName,
    this.pictureUrl,
  });
}
