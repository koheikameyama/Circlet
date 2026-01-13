import 'dart:html' as html;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'logger_service.dart';

class LineLoginWeb {
  static const String channelId = '2008326126'; // LINEチャネルID

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Callback URLを取得
  String get redirectUri {
    final origin = html.window.location.origin;
    return origin; // ハッシュモードの場合はルートパスのみ
  }

  // LINE Loginを開始
  void startLogin() {
    final state = _generateRandomString(32);
    final nonce = _generateRandomString(32);

    // セッションストレージに保存
    html.window.sessionStorage['line_login_state'] = state;
    html.window.sessionStorage['line_login_nonce'] = nonce;

    // デバッグログ: redirect_uriを確認
    AppLogger.info('LINE Login redirectUri: $redirectUri');
    AppLogger.info('Current URL: ${html.window.location.href}');

    final params = {
      'response_type': 'code',
      'client_id': channelId,
      'redirect_uri': redirectUri,
      'state': state,
      'scope': 'profile openid email',
      'nonce': nonce,
    };

    final uri = Uri.https('access.line.me', '/oauth2/v2.1/authorize', params);
    AppLogger.info('LINE Login URL: ${uri.toString()}');
    html.window.location.href = uri.toString();
  }

  // コールバック処理
  Future<UserCredential?> handleCallback() async {
    try {
      final uri = Uri.parse(html.window.location.href);
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];

      if (code == null) {
        throw Exception('Authorization code not found');
      }

      // stateを検証
      final savedState = html.window.sessionStorage['line_login_state'];
      if (state != savedState) {
        throw Exception('Invalid state parameter');
      }

      AppLogger.info('Calling Firebase Function for LINE login');

      // Firebase Functionsを呼び出してカスタムトークンを取得
      final result = await _functions.httpsCallable('lineLogin').call({
        'code': code,
        'redirectUri': redirectUri,
      });

      final data = result.data;
      final customToken = data['customToken'] as String;
      final profile = data['profile'] as Map<String, dynamic>;

      AppLogger.info('Got custom token, signing in: ${profile['userId']}');

      // カスタムトークンでFirebaseにサインイン
      final credential = await _auth.signInWithCustomToken(customToken);

      AppLogger.info('Successfully signed in: ${credential.user?.uid}');

      return credential;
    } catch (e) {
      AppLogger.error('LINE Web Login error: $e');
      return null;
    }
  }

  // ランダム文字列を生成
  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var result = '';
    for (var i = 0; i < length; i++) {
      result += chars[(random + i) % chars.length];
    }
    return result;
  }
}
