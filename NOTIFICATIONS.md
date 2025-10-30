# 通知機能の実装

Circletアプリには、以下の6種類の通知機能が実装されています。

## 実装済みの通知

### 1. イベント作成時の通知 ✅
**対象**: サークルメンバー全員
**タイミング**: イベント作成直後
**内容**: 「新しいイベントが作成されました - [イベント名] が [日時] に開催されます」

### 2. イベント更新時の通知 ✅
**対象**: イベント参加者（確定のみ）
**タイミング**: イベントの名前、日時、場所が変更されたとき
**内容**: 「イベント情報が更新されました - [イベント名] の情報が変更されました」

### 3. 定員到達時の通知 ✅
**対象**: サークル管理者
**タイミング**: 参加者が定員に達した瞬間
**内容**: 「イベントが定員に達しました - [イベント名] の参加者が定員に達しました」

### 4. キャンセル待ち繰り上がり時の通知 ✅
**対象**: 繰り上げられた参加者
**タイミング**: 確定参加者がキャンセルして繰り上がった直後
**内容**: 「イベント参加が確定しました - [イベント名] のキャンセル待ちから参加予定に変更されました」

### 5. イベント前日リマインド ✅
**対象**: イベント参加者（確定のみ）
**タイミング**: 毎日朝9時（日本時間）にCloud Schedulerが実行
**内容**: 「イベントリマインダー - [イベント名] が明日開催されます」

### 6. イベント終了後の未払通知 ✅
**対象**: 未払い参加者 + サークル管理者
**タイミング**: 毎時0分にCloud Schedulerが実行、1時間前に終了したイベントをチェック
**内容**:
- 参加者: 「参加費のお支払いをお願いします - [イベント名] の参加費 ¥[金額] のお支払いが未完了です」
- 管理者: 「未払いの参加者がいます - [イベント名] に[人数]名の未払い参加者がいます」

## アーキテクチャ

### アプリ側（Flutter）

**lib/services/notification_service.dart**
- FCMトークンの取得と保存
- フォアグラウンド通知のハンドリング
- Firestoreに通知レコードを作成

**lib/services/event_service.dart**
- イベント作成・更新・参加時に通知を送信
- NotificationServiceを呼び出して通知レコードを作成

**lib/main.dart**
- アプリ起動時に通知を初期化
- ログイン時にFCMトークンを保存

### Cloud Functions側（Node.js）

**functions/index.js**

1. **sendNotificationOnCreate** (Firestoreトリガー)
   - `notifications/{notificationId}` の作成を監視
   - 受信者のFCMトークンを取得
   - FCMメッセージを送信

2. **sendEventReminders** (Cloud Scheduler)
   - スケジュール: `0 9 * * *` (毎日 9:00 JST)
   - 明日開催されるイベントを検索
   - 参加者に通知レコードを作成

3. **sendPaymentReminders** (Cloud Scheduler)
   - スケジュール: `0 * * * *` (毎時 0分)
   - 1時間前に終了したイベントを検索
   - 未払い参加者と管理者に通知レコードを作成

## 通知の流れ

```
[アプリ側]
1. イベント作成/更新/参加処理
   ↓
2. NotificationService.sendBulkNotification()
   ↓
3. Firestoreに通知レコードを作成
   ↓

[Cloud Functions側]
4. Firestoreトリガーが発火
   ↓
5. 受信者のFCMトークンを取得
   ↓
6. FCMメッセージを送信
   ↓

[デバイス]
7. プッシュ通知が届く
```

## セットアップ手順

### 1. Cloud Functionsのデプロイ

```bash
# プロジェクトルートで実行
firebase deploy --only functions
```

### 2. Cloud Schedulerの有効化

初回デプロイ後、[Cloud Scheduler Console](https://console.cloud.google.com/cloudscheduler?project=circlet-9ee47)で以下のジョブを確認：

- `sendEventReminders`: 毎日 9:00 JST
- `sendPaymentReminders`: 毎時 0分

### 3. FCMの設定（既に完了）

- Firebase ConsoleでFCMが有効化されている
- アプリにfirebase_messagingパッケージがインストール済み
- AndroidManifest.xml、Info.plistに必要な設定が完了

## ローカル開発

### エミュレータで通知をテスト

```bash
# エミュレータを起動
firebase emulators:start
```

エミュレータ起動中は、Firestoreに通知レコードを作成すると、Cloud FunctionsがローカルでFCMメッセージを送信しようとします（ただし、実際のデバイスには届きません）。

### 通知レコードを手動で作成してテスト

```dart
// Flutterアプリから
await notificationService.sendNotification(
  circleId: 'test-circle-id',
  recipientUserId: 'test-user-id',
  title: 'テスト通知',
  body: 'これはテストです',
);
```

## トラブルシューティング

### 通知が届かない場合

1. **FCMトークンが保存されているか確認**
   ```
   Firestore > users > {userId} > fcmToken
   ```

2. **Cloud Functionsのログを確認**
   ```bash
   firebase functions:log --only sendNotificationOnCreate
   ```

3. **通知権限が許可されているか確認**
   - iOS: 設定 > Circlet > 通知
   - Android: 設定 > アプリ > Circlet > 通知

### Cloud Schedulerが実行されない場合

1. **ジョブが有効化されているか確認**
   - [Cloud Scheduler Console](https://console.cloud.google.com/cloudscheduler?project=circlet-9ee47)

2. **手動でジョブを実行してテスト**
   ```bash
   gcloud scheduler jobs run sendEventReminders --location=asia-northeast1
   gcloud scheduler jobs run sendPaymentReminders --location=asia-northeast1
   ```

## コスト

### Firebase Cloud Functions
- **無料枠**: 月間2,000,000回の呼び出し
- **現在の使用量**:
  - Firestoreトリガー: 通知レコード作成ごとに1回
  - Cloud Scheduler: 1日25回 (9時のリマインド + 24回の支払いチェック)

### Cloud Scheduler
- **無料枠**: 1日3ジョブまで無料
- **現在の使用量**: 2ジョブ（リマインド、支払いチェック）

### FCM (Firebase Cloud Messaging)
- **完全無料**: 無制限

## 今後の拡張案

- [ ] 通知設定画面（通知のON/OFF）
- [ ] 通知履歴画面（過去の通知を確認）
- [ ] リッチ通知（画像付き、アクション付き）
- [ ] カスタムリマインド（イベント3日前、1週間前など）
- [ ] グループ通知（同じイベントの通知をまとめる）
