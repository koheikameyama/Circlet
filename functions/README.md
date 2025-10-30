# Circlet Cloud Functions

このディレクトリには、Circletアプリ用のCloud Functionsが含まれています。

## 機能

### 1. sendNotificationOnCreate (Firestoreトリガー)
通知レコードがFirestoreに作成されたときに自動的にFCMプッシュ通知を送信します。

**トリガー**: `notifications/{notificationId}` の作成時

**処理内容**:
- 受信者のFCMトークンを取得
- FCMメッセージを作成
- 複数の受信者に一括送信

### 2. sendEventReminders (Cloud Scheduler)
毎日朝9時（日本時間）に実行され、明日開催されるイベントの参加者にリマインド通知を送信します。

**スケジュール**: `0 9 * * *` (毎日 9:00 JST)

**処理内容**:
- 明日開催されるイベントを検索
- 参加者（確定のみ）に通知レコードを作成
- 通知レコード作成により、sendNotificationOnCreateが自動実行される

### 3. sendPaymentReminders (Cloud Scheduler)
毎時0分に実行され、1時間前に終了したイベントの未払い参加者と管理者に通知を送信します。

**スケジュール**: `0 * * * *` (毎時 0分)

**処理内容**:
- 1時間前に終了したイベントを検索
- 参加者の支払い状況をチェック
- 未払い参加者に通知
- 管理者にも未払い者がいる旨を通知

## ローカル開発

### エミュレータで実行

```bash
# プロジェクトルートで実行
firebase emulators:start
```

これにより、Functions、Firestore、Auth、Storageのエミュレータが起動します。

### Functions単体で実行

```bash
cd functions
npm run serve
```

## デプロイ

### すべてのFunctionsをデプロイ

```bash
# プロジェクトルートから
firebase deploy --only functions

# または functions ディレクトリから
npm run deploy
```

### 特定のFunctionをデプロイ

```bash
firebase deploy --only functions:sendNotificationOnCreate
firebase deploy --only functions:sendEventReminders
firebase deploy --only functions:sendPaymentReminders
```

## Cloud Schedulerの設定

初回デプロイ後、以下のコマンドでCloud Schedulerのジョブを有効化します：

```bash
# Google Cloud Consoleで確認
# https://console.cloud.google.com/cloudscheduler?project=circlet-9ee47
```

## ログの確認

```bash
# すべてのログを表示
firebase functions:log

# 特定のFunctionのログを表示
firebase functions:log --only sendNotificationOnCreate
```

## 注意事項

1. **Node.jsバージョン**
   - 現在Node.js 20を使用しています
   - ローカル開発環境もNode.js 20を推奨

2. **FCMトークンの管理**
   - ユーザーがログインした際に、NotificationService.initializeNotifications()を呼び出してFCMトークンをFirestoreに保存する必要があります

3. **Cloud Schedulerの料金**
   - 無料枠: 1日3ジョブまで無料
   - 現在2つのジョブを使用（毎日リマインド、毎時支払いチェック）

4. **タイムゾーン**
   - すべてのスケジュールは日本時間（Asia/Tokyo）で設定されています

5. **エラーハンドリング**
   - すべてのエラーはログに記録されますが、処理は継続されます
   - Cloud Consoleでログを定期的にチェックすることを推奨

## トラブルシューティング

### 通知が届かない場合

1. ユーザーのFCMトークンが保存されているか確認
   ```javascript
   // Firestoreで確認
   users/{userId} -> fcmToken
   ```

2. Cloud Functionsのログを確認
   ```bash
   firebase functions:log --only sendNotificationOnCreate
   ```

3. FCMの送信ステータスを確認
   - ログに `Successfully sent X messages` と表示されるか確認

### Cloud Schedulerが実行されない場合

1. ジョブが有効化されているか確認
   - [Cloud Scheduler Console](https://console.cloud.google.com/cloudscheduler?project=circlet-9ee47)

2. ジョブの実行履歴を確認
   - 実行時刻とステータスを確認

3. 手動でジョブを実行してテスト
   ```bash
   gcloud scheduler jobs run sendEventReminders --location=asia-northeast1
   gcloud scheduler jobs run sendPaymentReminders --location=asia-northeast1
   ```
