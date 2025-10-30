# リリースチェックリスト

本番環境へのリリース前に、以下の項目を確認してください。

## 1. Firebase設定

### 1.1 プロジェクト設定
- [ ] Firebase Consoleでプロジェクト設定を確認
- [ ] 本番環境のプロジェクトIDが正しい (`circlet-9ee47`)

### 1.2 Android設定
- [ ] SHA-1フィンガープリント（Debug）が登録されている
  ```bash
  cd android && ./gradlew signingReport | grep "SHA1:" | head -1
  ```
- [ ] SHA-1フィンガープリント（Release）が登録されている
  ```bash
  keytool -list -v -keystore <release-keystore> -alias <alias>
  ```
- [ ] `android/app/google-services.json` が最新版
- [ ] パッケージ名が正しい (`com.circlet.app`)

### 1.3 iOS設定
- [ ] `ios/Runner/GoogleService-Info.plist` が最新版
- [ ] Bundle IDが正しい (`com.circlet.app`)
- [ ] APNs証明書がFirebase Consoleに登録されている（プッシュ通知用）
  - プロジェクト設定 → Cloud Messaging → APNs証明書

## 2. プッシュ通知設定

### 2.1 FCM（Firebase Cloud Messaging）
- [ ] Androidで通知権限が正しく要求される
- [ ] iOSで通知権限が正しく要求される
- [ ] FCMトークンがFirestoreに保存される（`users/{userId}/fcmToken`）
- [ ] フォアグラウンドで通知を受信できる
- [ ] バックグラウンドで通知を受信できる

### 2.2 Cloud Functions
- [ ] Cloud Functionsがデプロイされている
  ```bash
  firebase deploy --only functions
  ```
- [ ] 以下の3つのFunctionが動作している：
  - [ ] `sendNotificationOnCreate` - 通知レコード作成時のFCM送信
  - [ ] `sendEventReminders` - 毎日9時のイベントリマインダー
  - [ ] `sendPaymentReminders` - 毎時の支払いリマインダー

### 2.3 通知タイプのテスト
各通知タイプが正しく送信・受信できることを確認：
- [ ] イベント作成通知
- [ ] イベント更新通知
- [ ] 定員到達通知
- [ ] キャンセル待ち繰り上げ通知
- [ ] イベント1日前リマインダー
- [ ] 支払いリマインダー

## 3. 認証・ログイン

### 3.1 LINE認証
- [ ] LINE Developer ConsoleでChannel IDが正しい
- [ ] `.env` ファイルに必要な環境変数が設定されている
- [ ] LINEログインが正常に動作する
- [ ] ログアウトが正常に動作する

### 3.2 ディープリンク
- [ ] 招待リンクが正しく動作する（`https://circlet.page.link/invite/<inviteId>`）
- [ ] Dynamic Linksの設定が正しい
- [ ] アプリがインストールされていない場合の動作確認（ストアへのリダイレクト）

## 4. Firestore

### 4.1 セキュリティルール
- [ ] `firestore.rules` が本番環境向けに設定されている
- [ ] テスト用の全許可設定（`allow read, write: if true;`）が残っていない
- [ ] 各コレクションに適切なアクセス制限がある

### 4.2 インデックス
- [ ] `firestore.indexes.json` が最新
- [ ] 必要な複合インデックスがすべて作成されている
- [ ] Firebase Consoleでインデックスのステータスを確認

## 5. Storage

### 5.1 セキュリティルール
- [ ] `storage.rules` が本番環境向けに設定されている
- [ ] ファイルサイズ制限が適切に設定されている
- [ ] 許可するファイル形式が制限されている（画像のみなど）

## 6. アプリビルド

### 6.1 環境変数
- [ ] `.env` ファイルが正しく設定されている
- [ ] 本番環境のAPIキーが設定されている
- [ ] デバッグ用のフラグがオフになっている

### 6.2 Firebase Emulator
- [ ] `lib/config/firebase_emulator_config.dart` でエミュレータ接続がオフ
  ```dart
  static const bool useEmulator = false; // 本番環境ではfalse
  ```

### 6.3 Android
- [ ] `android/app/build.gradle` のバージョンコードを更新
- [ ] `android/app/build.gradle` のバージョン名を更新
- [ ] ProGuard設定が適切（`proguard-rules.pro`）
- [ ] リリースビルドが成功する
  ```bash
  flutter build apk --release
  # または
  flutter build appbundle --release
  ```

### 6.4 iOS
- [ ] `ios/Runner/Info.plist` のバージョン番号を更新
- [ ] `ios/Runner/Info.plist` のビルド番号を更新
- [ ] 必要な権限説明文が設定されている：
  - [ ] カメラ（`NSCameraUsageDescription`）
  - [ ] フォトライブラリ（`NSPhotoLibraryUsageDescription`）
  - [ ] 通知（`NSUserNotificationUsageDescription`）
- [ ] リリースビルドが成功する
  ```bash
  flutter build ios --release
  ```

## 7. テスト

### 7.1 機能テスト
- [ ] サークル作成・編集・削除
- [ ] イベント作成・編集・削除・参加・キャンセル
- [ ] キャンセル待ち機能
- [ ] 支払い管理機能
- [ ] メンバー管理機能
- [ ] 画像アップロード機能
- [ ] QRコード生成・読み取り機能

### 7.2 パフォーマンステスト
- [ ] 大量のイベントデータでの動作確認
- [ ] 大量のメンバーでの動作確認
- [ ] 画像の読み込み速度確認
- [ ] アプリ起動時間の確認

### 7.3 エラーハンドリング
- [ ] ネットワークエラー時の動作
- [ ] 権限拒否時の動作
- [ ] 不正なデータ入力時の動作

## 8. ドキュメント

- [ ] `README.md` が最新
- [ ] `FIREBASE_SETUP.md` が最新
- [ ] `NOTIFICATIONS.md` が最新
- [ ] `WEBSITE_INFO.md` が最新
- [ ] `functions/README.md` が最新
- [ ] API仕様書が最新（存在する場合）

## 9. ストア申請準備

### 9.1 Google Play Store
- [ ] アプリアイコンが設定されている
- [ ] スクリーンショットを準備（最低2枚、推奨8枚）
- [ ] アプリ説明文を準備
- [ ] プライバシーポリシーのURLを準備
- [ ] ストアリスティングの情報を確認

### 9.2 Apple App Store
- [ ] アプリアイコンが設定されている
- [ ] スクリーンショットを準備（各デバイスサイズ）
- [ ] アプリ説明文を準備
- [ ] プライバシーポリシーのURLを準備
- [ ] App Store Connectで必要情報を入力

## 10. 監視・ログ

### 10.1 Firebase Analytics
- [ ] Firebase Analyticsが有効化されている
- [ ] 重要なイベントがログされている

### 10.2 Crashlytics
- [ ] Firebase Crashlyticsが有効化されている
- [ ] クラッシュレポートが正しく送信される

### 10.3 Cloud Functions
- [ ] Cloud Functionsのログが確認できる
  ```bash
  firebase functions:log
  ```
- [ ] エラー通知が設定されている（Cloud Monitoringなど）

## 11. セキュリティ

- [ ] APIキーが公開されていない
- [ ] デバッグ情報が本番ビルドに含まれていない
- [ ] 機密情報がGitにコミットされていない（`.gitignore`を確認）
- [ ] ユーザーデータが適切に保護されている
- [ ] HTTPS通信のみ使用している

## 12. 法的事項

- [ ] プライバシーポリシーが最新
- [ ] 利用規約が最新
- [ ] 必要なライセンス表記がある
- [ ] GDPRなどの規制に準拠している（該当する場合）

## 13. バックアップ・復旧計画

- [ ] Firestoreのバックアップ設定を確認
- [ ] 重大な問題発生時のロールバック手順を確認
- [ ] 緊急連絡先リストを準備

## リリース後の確認

### 初日
- [ ] クラッシュレートを確認（Crashlytics）
- [ ] 通知送信が正常に動作しているか確認
- [ ] ユーザーからの問い合わせに対応

### 1週間後
- [ ] アクティブユーザー数を確認（Analytics）
- [ ] パフォーマンス指標を確認
- [ ] ユーザーレビューを確認
- [ ] 必要に応じてホットフィックスを準備

## トラブルシューティング

### 通知が届かない場合
1. Firestoreで `users/{userId}/fcmToken` を確認
2. Cloud Functionsのログを確認
   ```bash
   firebase functions:log --only sendNotificationOnCreate
   ```
3. デバイスの通知設定を確認
4. Google Play Services（Android）が最新か確認
5. APNs証明書（iOS）が有効か確認

### Cloud Schedulerが実行されない場合
1. [Cloud Scheduler Console](https://console.cloud.google.com/cloudscheduler?project=circlet-9ee47) で状態確認
2. 手動でジョブを実行してテスト
   ```bash
   gcloud scheduler jobs run sendEventReminders --location=asia-northeast1
   ```
3. Cloud Functionsのログを確認

---

## チェックリスト完了確認

全ての項目にチェックが入ったら、以下に署名してください：

- リリース担当者: ________________
- 日付: ________________
- バージョン: ________________

リリース承認: ________________
