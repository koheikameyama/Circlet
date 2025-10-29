# Circlet - サークル管理アプリ

既存サークルの運営を効率化するためのFlutterアプリです。メンバー管理、イベント管理、参加費管理、通知、カレンダー連携を一括管理できます。

## 主な機能

### 運営側（管理者）機能

#### サークル管理
- **サークル作成・編集**: サークル名、説明の設定
- **招待URL生成**: メンバー招待用のURLを生成・共有
- **メンバー管理**:
  - メンバー一覧表示（管理者/メンバーの区別）
  - 権限変更（管理者 ⇔ メンバー）
  - メンバー削除
  - 最低1人の管理者を維持する安全機能
  - サークルごとの表示名設定（ニックネーム、愛称など）
  - ダミーメンバー追加（テスト用）
- **権限変更UI**:
  - 三点リーダーメニューによる操作
  - 管理者が1人だけの場合は権限変更を制限
  - 確認ダイアログによる誤操作防止

#### イベント管理
- **イベント作成・編集**:
  - イベント名、説明
  - 日時（開始・終了）
    - 終日設定サポート
    - 過去日時の場合は確認ダイアログ表示
  - 公開日時設定（任意）
    - 設定した日時まで参加者に非表示
    - 管理者は常に参加可能
    - 終日イベントの場合は開始日の前日まで設定可能
  - キャンセル期限設定（任意）
    - 期限後は参加者のキャンセル不可
    - 管理者は期限後もキャンセル可能
    - 公開日時以降、開始日時以前で設定可能
    - 終日イベントの場合は開始日の前日まで設定可能
  - 場所（Google Places API統合）
  - 定員設定
  - 参加費設定
- **イベント削除**: 関連する支払い情報も一括削除
- **イベント表示**:
  - 非公開イベントは暗く表示（50%透明度）
  - リストビューとカレンダービューで統一
- **参加者管理**:
  - 参加者一覧表示（専用ページ）
  - 参加ステータスの手動変更
    - 参加確定 → キャンセル待ち
    - キャンセル待ち → 参加確定
    - キャンセル（削除）
  - ステータス変更の条件制御
    - 定員に空きがある場合：「参加確定」「キャンセル」のみ
    - 定員に空きがない場合：「参加確定」「キャンセル待ち」「キャンセル」
  - 三点リーダーメニューからの直感的な操作
- **キャンセル待ち管理**:
  - 自動採番
  - ユーザー自身がキャンセルした場合の自動繰り上げ
  - 管理者が手動でステータス変更する場合は自動繰り上げなし

#### 支払い管理
- **参加費管理**:
  - 各参加者の支払いステータスをチェックボックスで管理
  - 支払い済み ⇔ 未払いの切り替え
  - 支払いレコードの自動作成
- **支払いサマリー**:
  - 支払い済み人数/総人数
  - 未払い人数
  - 合計金額の集計

### 参加者側（メンバー）機能

#### サークル
- サークル一覧表示
- サークル情報の閲覧
- サークルへの参加（招待URL経由）

#### イベント
- **イベント参加**:
  - イベント一覧表示（非公開イベントは暗く表示）
  - 参加登録（定員内：確定、定員超過：キャンセル待ち）
  - 公開日時前のイベントには参加不可
  - 参加キャンセル
    - キャンセル期限後はキャンセル不可
    - 期限後は「管理者に連絡してください」メッセージを表示
- **イベント詳細**:
  - 日時、場所、定員、参加費の確認
  - 参加状況サマリー（参加確定数、キャンセル待ち数）
  - Google Maps連携（場所を地図で表示）
- **参加者一覧**: 専用ページで他の参加者を確認

#### 支払い
- 自分の支払いステータスの確認

## 技術スタック

- **フレームワーク**: Flutter 3.19.5
- **状態管理**: Riverpod 2.4.9
  - StreamProvider.autoDispose による効率的なリソース管理
  - ログアウト時の自動クリーンアップ
- **ルーティング**: go_router 13.0.0
- **認証**: Firebase Auth
- **データベース**: Cloud Firestore
  - リアルタイムストリーム更新
  - セキュリティルール適用
- **地図・場所検索**: Google Places API
- **通知**: Firebase Cloud Messaging（予定）
- **カレンダー**: device_calendar 4.3.3（予定）

## プロジェクト構成

```
lib/
├── config/              # 設定ファイル
│   └── api_keys.dart    # APIキー管理
├── models/              # データモデル
│   ├── user_model.dart
│   ├── circle_model.dart
│   ├── event_model.dart
│   └── payment_model.dart
├── services/            # ビジネスロジック
│   ├── auth_service.dart
│   ├── circle_service.dart
│   ├── event_service.dart
│   └── payment_service.dart
├── providers/           # Riverpod Providers
│   ├── auth_provider.dart
│   ├── circle_provider.dart
│   ├── event_provider.dart
│   └── payment_provider.dart
├── screens/             # UI画面
│   ├── auth/           # 認証関連
│   │   ├── login_screen.dart
│   │   └── circle_selection_screen.dart
│   ├── admin/          # 管理者画面
│   │   ├── admin_home_screen.dart
│   │   ├── admin_event_detail_screen.dart
│   │   └── admin_event_participants_screen.dart
│   └── participant/    # メンバー画面
│       ├── participant_home_screen.dart
│       ├── participant_event_detail_screen.dart
│       └── participant_event_participants_screen.dart
└── main.dart           # エントリーポイント
```

## セットアップ手順

### 1. 前提条件

- Flutter SDK 3.19.5以上
- Dart 3.3.3以上
- Firebase プロジェクト
- Google Places API キー

### 2. Firebaseのセットアップ

1. [Firebase Console](https://console.firebase.google.com/)でプロジェクトを作成
2. iOS/Androidアプリを登録
3. `google-services.json` (Android) と `GoogleService-Info.plist` (iOS) をダウンロード
4. Firebaseの設定ファイルを配置:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

5. Firestoreセキュリティルールを設定（`firestore.rules`）:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 認証必須
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 3. Google Places APIのセットアップ

1. [Google Cloud Console](https://console.cloud.google.com/)でプロジェクトを作成
2. Places APIを有効化
3. APIキーを取得
4. `lib/config/api_keys.dart`を作成:

```dart
class ApiKeys {
  static const String googlePlacesApiKey = 'YOUR_API_KEY_HERE';
}
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

```dart
{
  "userId": "string",
  "name": "string",
  "email": "string",
  "createdAt": "timestamp"
}
```

### Circles Collection

```dart
{
  "circleId": "string",
  "name": "string",
  "description": "string?",
  "inviteToken": "string",         // 招待用トークン
  "members": [
    {
      "userId": "string",
      "role": "admin" | "member",   // 権限
      "displayName": "string?",     // サークル内での表示名（任意）
      "tags": ["string"],
      "joinedAt": "timestamp"
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Events Collection

```dart
{
  "eventId": "string",
  "circleId": "string",
  "name": "string",
  "description": "string?",
  "datetime": "timestamp",               // 開始日時
  "endDatetime": "timestamp?",           // 終了日時
  "publishDatetime": "timestamp?",       // 公開日時（任意）
  "cancellationDeadline": "timestamp?",  // キャンセル期限（任意）
  "location": "string?",                 // 場所
  "maxParticipants": "number",           // 定員
  "fee": "number?",                      // 参加費
  "participants": [
    {
      "userId": "string",
      "status": "confirmed" | "waitlist" | "cancelled",
      "waitingNumber": "number?",        // キャンセル待ち番号
      "registeredAt": "timestamp"        // 登録日時
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Payments Collection

```dart
{
  "paymentId": "string",
  "userId": "string",
  "eventId": "string",
  "circleId": "string",
  "amount": "number",
  "status": "pending" | "completed" | "cancelled",
  "method": "cash" | "paypay" | "bank_transfer",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## 状態管理のベストプラクティス

### StreamProviderの自動破棄

すべてのStreamProviderに`autoDispose`を適用し、画面が破棄されるとFirestoreストリームも自動的にキャンセルされます。

```dart
final currentUserProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);

  final authService = ref.watch(authServiceProvider);
  return authService.getUserDataStream(userId);
});
```

### ログアウト時の処理順

Firestoreセキュリティルール（`request.auth != null`）により、ログアウト時の権限エラーを防ぐため、以下の順序で処理：

1. 画面遷移を実行（StreamProviderがdisposeされる）
2. 100ms待機（dispose完了を待つ）
3. サインアウト実行

これにより、認証が解除される前にFirestoreストリームが適切にクリーンアップされます。

## UI/UXの特徴

### レスポンシブデザイン
- モバイルファーストの設計
- カードベースの見やすいレイアウト
- 直感的なアイコンとカラーコーディング

### ナビゲーション
- タブベースのナビゲーション（イベント、メンバー、支払い）
- 階層的な画面遷移
- 戻るボタンによる直感的な操作

### データ表示
- **サマリーカード**: 重要な情報を一目で確認
- **専用ページ**: 詳細情報は別ページで表示（参加者一覧など）
- **リアルタイム更新**: Firestoreストリームによる自動反映

### 操作の安全性
- 重要な操作には確認ダイアログ
- ビジネスルールの自動適用
  - 最低1人の管理者を維持
  - 定員チェック
  - キャンセル待ちの自動採番
- エラーメッセージとフィードバックの明確な表示

## 開発ガイドライン

### UI変更時の注意事項

このアプリには管理者画面とメンバー画面があり、多くの画面が対応関係にあります。UI変更を行う際は、**両方の画面で統一性を保つ**必要があります。

詳細は [画面対応表](docs/screen-mapping.md) を参照してください。

**チェックコマンド:**
```
/check-both-screens
```

### 開発中のデバッグ機能

以下のデバッグ機能が実装されています（本番環境では削除または制限を推奨）：

- **ダミーメンバー追加**: サークルメンバータブから5人のテストメンバーを一括追加
- **ダミー参加者追加**: イベント参加者一覧からサークルメンバーを参加者として追加
- **自動イベント作成**: 管理者ホーム画面からテストイベントを自動生成

## 今後の実装予定

- [ ] プッシュ通知
  - イベントリマインダー
  - キャンセル待ちからの繰り上げ通知
  - 支払いリマインダー
- [ ] PayPay API連携
- [ ] カレンダー連携
  - 参加確定時に自動追加
  - キャンセル時に自動削除
- [ ] プロフィール画像のアップロード
- [ ] イベント画像の追加
- [ ] 統計・レポート機能
- [ ] エクスポート機能（CSV等）
- [ ] 多言語対応

## トラブルシューティング

### ログアウト時の権限エラー

**問題**: ログアウト時に `permission-denied` エラーが発生

**原因**: Firestoreストリームがアクティブなまま認証が解除される

**解決**:
- すべてのStreamProviderに`autoDispose`を追加済み
- ログアウト時の処理順を最適化済み

### 参加者ステータスが更新されない

**問題**: ステータスを変更しても反映されない

**原因**: StreamProviderがキャッシュを保持している

**解決**: `autoDispose`により画面遷移時に自動的にリフレッシュされます

## ライセンス

This project is private and not licensed for public use.

## お問い合わせ

開発に関する質問や問題がある場合は、Issuesを作成してください。
