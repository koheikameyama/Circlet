# Firebase セットアップガイド

このドキュメントでは、Grumaneアプリで使用するFirebaseプロジェクトのセットアップ手順を説明します。

## 1. Firebaseプロジェクトの作成

### 1.1 Firebase Consoleにアクセス
1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. Googleアカウントでログイン
3. 「プロジェクトを追加」をクリック

### 1.2 プロジェクト情報の入力
1. **プロジェクト名**: `grumane` または任意の名前を入力
2. Google Analyticsの有効化（推奨: 有効）
3. Analyticsアカウントの選択または新規作成
4. 「プロジェクトを作成」をクリック

## 2. Firebaseアプリの登録

### 2.1 iOSアプリの登録
1. Firebase Consoleのプロジェクトダッシュボードで「iOS」アイコンをクリック
2. 以下の情報を入力:
   - **iOSバンドルID**: `com.grumane.grumane`
   - **アプリのニックネーム**: `Grumane iOS` (任意)
   - **App Store ID**: (後で追加可能)
3. 「アプリを登録」をクリック
4. `GoogleService-Info.plist`ファイルをダウンロード
5. ダウンロードしたファイルを `ios/Runner/` ディレクトリに配置

### 2.2 Androidアプリの登録
1. Firebase Consoleのプロジェクトダッシュボードで「Android」アイコンをクリック
2. 以下の情報を入力:
   - **Androidパッケージ名**: `com.grumane.grumane`
   - **アプリのニックネーム**: `Grumane Android` (任意)
   - **デバッグ用の署名証明書 SHA-1**: (任意、後で追加可能)
3. 「アプリを登録」をクリック
4. `google-services.json`ファイルをダウンロード
5. ダウンロードしたファイルを `android/app/` ディレクトリに配置

## 3. FlutterFire CLIで設定を生成

### 3.1 Firebase CLIのインストール（未インストールの場合）
```bash
# Node.jsがインストールされている場合
npm install -g firebase-tools

# Homebrewを使用する場合（macOS）
brew install firebase-cli
```

### 3.2 Firebaseにログイン
```bash
firebase login
```

### 3.3 FlutterFire CLIの実行
```bash
# プロジェクトディレクトリで実行
export PATH="$HOME/flutter/bin:$PATH"
export PATH="$PATH:$HOME/.pub-cache/bin"
flutterfire configure
```

このコマンドは以下を行います:
- Firebaseプロジェクトの選択
- `lib/firebase_options.dart`ファイルの自動生成
- iOS/Android設定の自動更新

## 4. Firebaseサービスの有効化

### 4.1 Authentication（認証）の設定
1. Firebase Console > 「Authentication」
2. 「始める」をクリック
3. 「Sign-in method」タブを選択
4. 以下のプロバイダーを有効化:
   - **匿名**: 有効にする（LINE認証のフォールバック用）
   - **Google**: （オプション）後で追加可能

### 4.2 Cloud Firestoreの設定
1. Firebase Console > 「Firestore Database」
2. 「データベースの作成」をクリック
3. **本番環境モード**を選択
4. ロケーション: `asia-northeast1` (東京) を推奨
5. 「有効にする」をクリック

#### Firestoreセキュリティルールの設定
1. Firestore Database > 「ルール」タブ
2. 以下のルールをコピー＆ペースト:

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
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null &&
        get(/databases/$(database)/documents/circles/$(resource.data.circleId)).data.adminId == request.auth.uid;
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

3. 「公開」をクリック

### 4.3 Cloud Storageの設定
1. Firebase Console > 「Storage」
2. 「始める」をクリック
3. セキュリティルールで「本番環境モード」を選択
4. ロケーション: `asia-northeast1` (東京) を推奨
5. 「完了」をクリック

#### Storageセキュリティルールの設定
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // ユーザープロフィール画像
    match /users/{userId}/profile/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // サークル画像
    match /circles/{circleId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // イベント画像
    match /events/{eventId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### 4.4 Cloud Messaging（FCM）の設定
1. Firebase Console > 「Cloud Messaging」
2. iOS/Androidアプリでプッシュ通知を有効化

**iOS追加設定:**
1. Xcodeでプロジェクトを開く: `open ios/Runner.xcworkspace`
2. Runner > Signing & Capabilities
3. 「+ Capability」をクリック
4. 「Push Notifications」を追加
5. 「Background Modes」を追加し、「Remote notifications」を有効化

**Android追加設定:**
- 自動的に設定されます（google-services.jsonに含まれています）

## 5. Firestoreインデックスの作成

複雑なクエリを使用するため、以下のインデックスを作成します:

1. Firebase Console > Firestore Database > 「インデックス」タブ
2. 「複合」タブで以下のインデックスを作成:

### events コレクション
- フィールド: `circleId` (昇順), `datetime` (昇順)
- クエリスコープ: コレクション

### payments コレクション
- フィールド: `userId` (昇順), `status` (昇順)
- クエリスコープ: コレクション

### notifications コレクション
- フィールド: `circleId` (昇順), `sentAt` (降順)
- クエリスコープ: コレクション

**注意**: アプリ実行時にエラーが発生した場合、コンソールに表示されるリンクから自動的にインデックスを作成できます。

## 6. LINE Login の設定

### 6.1 LINE Developers Console
1. [LINE Developers Console](https://developers.line.biz/console/)にアクセス
2. プロバイダーを作成（既存のプロバイダーがある場合はそれを使用）
3. 新しいチャネルを作成:
   - チャネルタイプ: **LINE Login**
   - アプリタイプ: **ネイティブアプリ**
4. 必要情報を入力して作成

### 6.2 Channel ID と Channel Secretの取得
1. 作成したチャネルの「Basic settings」タブ
2. **Channel ID** をコピー
3. **Channel Secret** をコピー

### 6.3 iOS設定
`ios/Runner/Info.plist`に以下を追加:

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
    <string>YOUR_LINE_CHANNEL_ID</string>
</dict>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>lineauth2</string>
</array>
```

### 6.4 Android設定
`android/app/src/main/AndroidManifest.xml`の`<application>`タグ内に追加:

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
            android:scheme="line3rdp.com.grumane.grumane" />
    </intent-filter>
</activity>
```

### 6.5 Callback URLの設定
LINE Developers Console > チャネル > 「LINE Login」タブ:
- **Callback URL**:
  - iOS: `line3rdp.com.grumane.grumane://authorize`
  - Android: `line3rdp.com.grumane.grumane://authorize`

## 7. アプリのビルドと実行

### 7.1 依存関係の確認
```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
```

### 7.2 ビルドエラーの解決
```bash
# iOSの場合
cd ios
pod install --repo-update
cd ..

# Androidの場合（必要に応じて）
cd android
./gradlew clean
cd ..
```

### 7.3 アプリの実行
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

## トラブルシューティング

### エラー: [core/no-app] No Firebase App '[DEFAULT]' has been created
- `firebase_options.dart`が正しく生成されているか確認
- `main.dart`で`Firebase.initializeApp()`が呼ばれているか確認

### エラー: Cloud Firestore permission denied
- Firestoreセキュリティルールが正しく設定されているか確認
- ユーザーが認証済みか確認

### iOS: Push Notificationsが動作しない
- Xcodeで「Push Notifications」capabilityが追加されているか確認
- Apple Developer Portalで証明書が正しく設定されているか確認

### Android: ビルドエラー
- `android/build.gradle`のGradleバージョンを確認
- `android/app/build.gradle`のminSdkVersionが21以上であることを確認

## 次のステップ

セットアップが完了したら:
1. テストユーザーでログインを試す
2. サークルを作成する
3. イベントを作成して参加機能をテスト
4. 通知機能のテスト

詳細は`README.md`を参照してください。
