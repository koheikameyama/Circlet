# Grumane - サークル管理アプリ

既存サークルの運営を効率化するためのFlutterアプリです。メンバー管理、イベント管理、参加費管理、通知、カレンダー連携を一括管理できます。

## 主な機能

### 運営側機能
- **メンバー管理**: メンバー一覧表示、追加（LINE招待リンク・QRコード）、編集、削除、タグ付け
- **イベント管理**: イベント作成・編集・削除、定員設定、キャンセル待ち管理（自動繰り上がり）
- **支払い管理**: 参加費一覧、PayPay連携、未払い者へのリマインド
- **通知管理**: 個別/全体通知送信、通知履歴確認

### 参加者側機能
- **イベント参加**: イベント一覧、参加登録、キャンセル、キャンセル待ち
- **メンバー一覧**: タグ・役職確認
- **支払い状況確認**: PayPay連携
- **通知確認**: 運営からの連絡・イベントリマインド
- **カレンダー連携**: 参加確定時に自動追加、キャンセル時に自動削除

## 技術スタック

- **フレームワーク**: Flutter 3.19.5
- **状態管理**: Riverpod 2.4.9
- **ルーティング**: go_router 13.0.0
- **認証**: Firebase Auth + LINE Login
- **データベース**: Cloud Firestore
- **通知**: Firebase Cloud Messaging
- **決済**: PayPay API (要実装)
- **カレンダー**: device_calendar 4.3.3

## プロジェクト構成

```
lib/
├── models/              # データモデル
│   ├── user_model.dart
│   ├── circle_model.dart
│   ├── event_model.dart
│   ├── payment_model.dart
│   └── notification_model.dart
├── services/            # ビジネスロジック
│   ├── auth_service.dart
│   ├── circle_service.dart
│   ├── event_service.dart
│   ├── payment_service.dart
│   ├── notification_service.dart
│   └── calendar_service.dart
├── providers/           # Riverpod Providers
│   ├── auth_provider.dart
│   ├── circle_provider.dart
│   └── event_provider.dart
├── screens/             # UI画面
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── circle_selection_screen.dart
│   ├── participant/
│   │   └── participant_home_screen.dart
│   └── admin/
│       └── admin_home_screen.dart
└── main.dart            # エントリーポイント
```

## セットアップ手順

### 1. 前提条件

- Flutter SDK 3.19.5以上
- Dart 3.3.3以上
- Firebase プロジェクト
- LINE Developers アカウント

### 2. Firebaseのセットアップ

1. [Firebase Console](https://console.firebase.google.com/)でプロジェクトを作成
2. iOS/Androidアプリを登録
3. `google-services.json` (Android) と `GoogleService-Info.plist` (iOS) をダウンロード
4. Firebaseの設定ファイルを配置:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

5. Firestoreセキュリティルールを設定:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザーコレクション
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // サークルコレクション
    match /circles/{circleId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null &&
        resource.data.adminId == request.auth.uid;
    }

    // イベントコレクション
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow create, update, delete: if request.auth != null;
    }

    // 支払いコレクション
    match /payments/{paymentId} {
      allow read: if request.auth != null &&
        (resource.data.userId == request.auth.uid ||
         get(/databases/$(database)/documents/circles/$(resource.data.circleId)).data.adminId == request.auth.uid);
      allow create, update: if request.auth != null;
    }

    // 通知コレクション
    match /notifications/{notificationId} {
      allow read: if request.auth != null &&
        request.auth.uid in resource.data.recipientUserIds;
      allow create: if request.auth != null;
    }
  }
}
```

### 3. LINE Loginのセットアップ

1. [LINE Developers Console](https://developers.line.biz/console/)でプロバイダーとチャネルを作成
2. Channel IDとChannel Secretを取得
3. iOSの設定:
   - `ios/Runner/Info.plist`に以下を追加:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>line3rdp.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </array>
    </dict>
</array>
<key>LineSDKConfig</key>
<dict>
    <key>ChannelID</key>
    <string>YOUR_CHANNEL_ID</string>
</dict>
```

4. Androidの設定:
   - `android/app/src/main/AndroidManifest.xml`に以下を追加:

```xml
<activity
    android:name="com.linecorp.linesdk.auth.LineAuthenticationActivity"
    android:exported="true"
    android:launchMode="singleTask">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:host="authorize"
            android:scheme="line3rdp.YOUR_PACKAGE_NAME" />
    </intent-filter>
</activity>
```

### 4. 依存関係のインストール

```bash
flutter pub get
```

### 5. アプリの実行

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

## データ構造

### Users Collection
```json
{
  "userId": "string",
  "name": "string",
  "lineUserId": "string",
  "profileImageUrl": "string?",
  "email": "string?",
  "circleIds": ["string"],
  "fcmToken": "string?",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Circles Collection
```json
{
  "circleId": "string",
  "name": "string",
  "description": "string",
  "iconUrl": "string?",
  "adminId": "string",
  "members": [
    {
      "userId": "string",
      "role": "string",
      "tags": ["string"],
      "joinedAt": "timestamp"
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Events Collection
```json
{
  "eventId": "string",
  "circleId": "string",
  "name": "string",
  "description": "string?",
  "datetime": "timestamp",
  "location": "string?",
  "maxParticipants": "number",
  "fee": "number?",
  "participants": [
    {
      "userId": "string",
      "status": "confirmed|waitlist|cancelled",
      "waitingNumber": "number?",
      "registeredAt": "timestamp"
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## 今後の実装予定

- [ ] PayPay API連携の完全実装
- [ ] Firebase Cloud Functions（通知送信、自動リマインダー）
- [ ] プロフィール画像のアップロード機能
- [ ] イベント画像の追加
- [ ] 詳細な統計情報
- [ ] エクスポート機能（CSV等）
- [ ] 多言語対応

## ライセンス

This project is private and not licensed for public use.

## お問い合わせ

開発に関する質問や問題がある場合は、Issuesを作成してください。
