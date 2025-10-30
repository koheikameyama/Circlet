# 本番リリースチェックリスト

このドキュメントは、アプリを本番環境（App Store / Google Play）にリリースする前に確認すべき項目をまとめています。

## 📱 iOS

### 1. Apple Developer Program
- [ ] Apple Developer Programに登録済み（$99/年）
- [ ] Team IDを取得済み

### 2. Universal Links設定
- [ ] `web/.well-known/apple-app-site-association` のTeam IDを更新
- [ ] Xcodeで Signing & Capabilities を設定
- [ ] Associated Domainsを追加: `applinks:circlet.jp`
- [ ] Firebase Hostingに再デプロイ: `firebase deploy --only hosting`

### 3. 招待URL確認
- [ ] HTTPS URL (`https://circlet.jp/invite/...`) が生成されることを確認
- [ ] Safari でリンクを開いてアプリが起動することを確認

## 🤖 Android

### 1. App Links設定
- [ ] リリース用キーストアで署名
- [ ] SHA256フィンガープリントを取得:
  ```bash
  keytool -list -v -keystore /path/to/release.keystore \
    -alias your-key-alias | grep SHA256
  ```
- [ ] `web/.well-known/assetlinks.json` のSHA256を更新
- [ ] Firebase Hostingに再デプロイ: `firebase deploy --only hosting`

### 2. 招待URL変更
- [ ] **重要**: `lib/services/circle_service.dart` の `generateInviteUrl` メソッドを変更

**変更箇所:**
```dart
// 変更前（開発環境）
String generateInviteUrl(String inviteId) {
  if (Platform.isIOS) {
    return 'https://circlet.jp/invite/$inviteId';
  }
  return 'circlet://invite/$inviteId';  // ← カスタムURLスキーム
}

// 変更後（本番環境）
String generateInviteUrl(String inviteId) {
  // iOS/Android両方でHTTPS URLを使用
  return 'https://circlet.jp/invite/$inviteId';
}
```

### 3. 招待URL確認
- [ ] HTTPS URL (`https://circlet.jp/invite/...`) が生成されることを確認
- [ ] Chrome でリンクを開いてアプリが起動することを確認
- [ ] App Linksの検証状態を確認:
  ```bash
  adb shell pm get-app-links com.circlet.app
  ```

## 🔧 共通設定

### 1. Firebase設定
- [ ] Firestoreセキュリティルールを確認
- [ ] Firebaseインデックスをデプロイ済み: `firebase deploy --only firestore:indexes`
- [ ] Firebase Hosting設定を確認
- [ ] 招待ページ (`web/invite.html`) の動作確認

### 2. コード確認
- [ ] デバッグコード・ログを削除
- [ ] ダミーデータ作成機能を削除/無効化
- [ ] APIキーが環境変数から読み込まれることを確認
- [ ] `.env` ファイルがgitignoreされていることを確認

### 3. ビルド設定
- [ ] バージョン番号を更新 (`pubspec.yaml`)
- [ ] リリースビルドでテスト:
  - iOS: `flutter build ios --release`
  - Android: `flutter build appbundle --release`

## 🧪 テスト

### iOS
- [ ] 実機でリリースビルドをテスト
- [ ] 招待リンクが正しく動作することを確認
- [ ] Universal Linksが動作することを確認
- [ ] TestFlightでベータテスト

### Android
- [ ] 実機でリリースビルドをテスト
- [ ] 招待リンクが正しく動作することを確認
- [ ] App Linksが動作することを確認
- [ ] Internal Testing / Closed Testing でベータテスト

## 📝 ドキュメント

- [ ] README.mdを更新
- [ ] 変更履歴を記録
- [ ] スクリーンショットを更新（App Store / Google Play用）

## 🚀 デプロイ

### App Store
- [ ] App Store Connectでアプリ情報を設定
- [ ] スクリーンショット・プレビュー動画をアップロード
- [ ] プライバシーポリシーのURLを設定
- [ ] アプリを提出してレビュー待ち

### Google Play
- [ ] Google Play Consoleでアプリ情報を設定
- [ ] スクリーンショット・紹介動画をアップロード
- [ ] プライバシーポリシーのURLを設定
- [ ] アプリを提出してレビュー待ち

## ⚠️ 重要な注意事項

### Android招待URL変更
**本番リリース前に必ず実施:**
- `lib/services/circle_service.dart` の `generateInviteUrl` を変更
- カスタムURLスキーム → HTTPS URL
- 詳細: `docs/universal-links-setup.md` 参照

### 確認方法
```bash
# コード内のTODOを検索
grep -r "TODO.*本番" lib/
```

---

## 参考ドキュメント

- [Universal Links（HTTPS招待URL）セットアップガイド](universal-links-setup.md)
- [Android招待リンクテストガイド](android-invite-testing.md)
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Store Guidelines](https://play.google.com/about/developer-content-policy/)
