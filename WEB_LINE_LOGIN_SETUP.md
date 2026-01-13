# Web版でLINEログインを実装する方法

## 概要

Web版でLINEログインを安全に実装するには、Firebase Cloud Functionsを使用してバックエンドでトークン交換を行う必要があります。

## 必要な設定

### 1. LINE Developers Console

1. [LINE Developers Console](https://developers.line.biz/)にアクセス
2. 既存のチャネルを選択（Channel ID: 2008326126）
3. **LINE Login** タブを開く
4. **Callback URL**に以下を追加：
   ```
   https://circlet-9ee47.web.app/line-callback
   https://localhost:8080/line-callback (開発用)
   ```

### 2. Channel Secretの取得

1. LINE Developers Consoleで **Basic settings** タブを開く
2. **Channel secret** をコピー
3. `.env` ファイルに追加：
   ```
   LINE_CHANNEL_SECRET=your_channel_secret_here
   ```

### 3. Firebase Functions実装

`functions/src/line-login.ts` を作成：

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';

export const lineLogin = functions.https.onCall(async (data, context) => {
  const { code, redirectUri } = data;

  if (!code) {
    throw new functions.https.HttpsError('invalid-argument', 'Code is required');
  }

  try {
    // アクセストークンを取得
    const tokenResponse = await axios.post(
      'https://api.line.me/oauth2/v2.1/token',
      new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: redirectUri,
        client_id: functions.config().line.channel_id,
        client_secret: functions.config().line.channel_secret,
      }),
      {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      }
    );

    const { access_token, id_token } = tokenResponse.data;

    // ユーザープロフィールを取得
    const profileResponse = await axios.get('https://api.line.me/v2/profile', {
      headers: { Authorization: `Bearer ${access_token}` },
    });

    const profile = profileResponse.data;

    // Firebaseカスタムトークンを生成
    const customToken = await admin.auth().createCustomToken(profile.userId, {
      lineUserId: profile.userId,
      displayName: profile.displayName,
      pictureUrl: profile.pictureUrl,
    });

    return {
      customToken,
      profile,
    };
  } catch (error) {
    console.error('LINE login error:', error);
    throw new functions.https.HttpsError('internal', 'LINE login failed');
  }
});
```

### 4. Firebase Functionsの設定

```bash
# LINE設定を追加
firebase functions:config:set line.channel_id="2008326126"
firebase functions:config:set line.channel_secret="YOUR_CHANNEL_SECRET"

# デプロイ
firebase deploy --only functions
```

### 5. Flutter側の実装

`lib/services/line_login_web.dart` を更新：

```dart
import 'dart:html' as html;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LineLoginWeb {
  static const String channelId = '2008326126';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String get redirectUri {
    final origin = html.window.location.origin;
    return '$origin/line-callback';
  }

  // LINE Loginを開始
  void startLogin() {
    final state = _generateRandomString(32);
    html.window.sessionStorage['line_login_state'] = state;

    final params = {
      'response_type': 'code',
      'client_id': channelId,
      'redirect_uri': redirectUri,
      'state': state,
      'scope': 'profile openid',
    };

    final uri = Uri.https('access.line.me', '/oauth2/v2.1/authorize', params);
    html.window.location.href = uri.toString();
  }

  // コールバック処理
  Future<UserCredential?> handleCallback() async {
    try {
      final uri = Uri.parse(html.window.location.href);
      final code = uri.queryParameters['code'];

      if (code == null) {
        throw Exception('Authorization code not found');
      }

      // Firebase Functionsを呼び出してカスタムトークンを取得
      final result = await _functions.httpsCallable('lineLogin').call({
        'code': code,
        'redirectUri': redirectUri,
      });

      final customToken = result.data['customToken'] as String;

      // カスタムトークンでFirebaseにサインイン
      final credential = await _auth.signInWithCustomToken(customToken);

      return credential;
    } catch (e) {
      print('LINE login error: $e');
      return null;
    }
  }

  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var result = '';
    for (var i = 0; i < length; i++) {
      result += chars[(random + i) % chars.length];
    }
    return result;
  }
}
```

## オプション2: 現状のままメール/パスワード認証を使用（推奨）

Web版では**メール/パスワード認証**を使い、モバイルアプリでは**LINEログイン**を使う方が実装が簡単で安全です。

### メリット
- セキュリティリスクがない
- 追加のバックエンド実装が不要
- すぐに使える

### デメリット
- ユーザーがメールアドレスとパスワードを覚える必要がある
- ソーシャルログインの利便性が失われる

## 推奨事項

**現時点では、Web版ではメール/パスワード認証を使用することを推奨します。**

将来的にWeb版でもソーシャルログインが必要になった場合は：
1. Google認証を追加（Web版でもネイティブサポート）
2. またはFirebase Functionsを実装してLINEログインを追加

## 参考リンク

- [LINE Login Documentation](https://developers.line.biz/ja/docs/line-login/)
- [Firebase Custom Tokens](https://firebase.google.com/docs/auth/admin/create-custom-tokens)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
