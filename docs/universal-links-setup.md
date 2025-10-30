# Universal Links（HTTPS招待URL）セットアップガイド

このドキュメントでは、開発環境から本番環境へHTTPS URLに切り替える手順を説明します。

## 現在の状態

**開発環境（現在）:**
- 招待URL: `circlet://invite/[inviteId]` （カスタムURLスキーム）
- Apple Developer Program: 不要
- 動作: iOS/Androidアプリ両方で動作

**本番環境（将来）:**
- 招待URL: `https://circlet.jp/invite/[inviteId]`
- Apple Developer Program: 必須（年間$99）
- 動作: WebブラウザでもシェアしやすいHTTPS URL

---

## 本番環境への切り替え手順

### ステップ1: Apple Developer Programへの登録

1. **Apple Developer Programに登録**
   - URL: https://developer.apple.com/programs/
   - 費用: 年間 $99（約12,000円）
   - 所要時間: 数日〜1週間

2. **Team IDを取得**
   - Apple Developer Console → Membership
   - Team IDをメモ（例: `ABCD123456`）

### ステップ2: iOS設定の更新

#### 2-1. apple-app-site-associationファイルを更新

```bash
# web/.well-known/apple-app-site-association を編集
```

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "YOUR_TEAM_ID.com.circlet.app",  // ← Team IDを実際の値に置き換え
        "paths": [
          "/invite/*"
        ]
      }
    ]
  }
}
```

**例:** Team IDが `ABCD123456` の場合
```json
"appID": "ABCD123456.com.circlet.app"
```

#### 2-2. Xcodeでの設定

1. **Xcodeでプロジェクトを開く**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Signing & Capabilitiesタブ**
   - Runner ターゲットを選択
   - "Signing & Capabilities" タブを開く
   - Team: 登録したDeveloper Accountを選択

3. **Associated Domainsの確認**
   - "Associated Domains" capabilityが追加されているか確認
   - なければ、"+ Capability" から追加
   - Domains:
     ```
     applinks:circlet.jp
     ```

### ステップ3: Android設定の更新

#### 3-1. 署名証明書のSHA256フィンガープリントを取得

**デバッグ用キーストア:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android | grep "SHA256"
```

**リリース用キーストア:**
```bash
keytool -list -v -keystore /path/to/your/release.keystore \
  -alias your-key-alias | grep "SHA256"
```

出力例:
```
SHA256: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90
```

#### 3-2. assetlinks.jsonを更新

```bash
# web/.well-known/assetlinks.json を編集
```

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.circlet.app",
      "sha256_cert_fingerprints": [
        "AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90",
        "取得したSHA256フィンガープリントに置き換え"
      ]
    }
  }
]
```

### ステップ4: コードの変更

#### circle_service.dartを編集

```bash
# lib/services/circle_service.dart の generateInviteUrl メソッドを変更
```

**変更前:**
```dart
String generateInviteUrl(String inviteId) {
  // 本番環境（Apple Developer Program登録後）はHTTPS URLを使用
  // return 'https://circlet.jp/invite/$inviteId';

  // 開発環境ではカスタムURLスキームを使用（Apple Developer Program不要）
  return 'circlet://invite/$inviteId';
}
```

**変更後:**
```dart
String generateInviteUrl(String inviteId) {
  // 本番環境: HTTPS URLを使用
  return 'https://circlet.jp/invite/$inviteId';

  // 開発環境用（必要に応じてコメント解除）
  // return 'circlet://invite/$inviteId';
}
```

### ステップ5: Firebase Hostingに再デプロイ

```bash
firebase deploy --only hosting
```

### ステップ6: 動作確認

#### iOS（実機）での確認

1. アプリをビルドして実機にインストール
   ```bash
   flutter run -d <device-id>
   ```

2. Safariで招待URLを開く
   ```
   https://circlet.jp/invite/test-invite-id
   ```

3. アプリが自動的に起動することを確認

#### Androidでの確認

1. アプリをビルドしてインストール
   ```bash
   flutter run -d <device-id>
   ```

2. Chromeで招待URLを開く
   ```
   https://circlet.jp/invite/test-invite-id
   ```

3. アプリが自動的に起動することを確認

---

## トラブルシューティング

### iOS Universal Linksが動作しない

**原因1: Team IDが間違っている**
- apple-app-site-associationのTeam IDを確認
- Apple Developer ConsoleのMembershipページで確認

**原因2: Associated Domainsが設定されていない**
- XcodeのSigning & Capabilitiesで確認
- `applinks:circlet.jp` が追加されているか

**原因3: apple-app-site-associationファイルにアクセスできない**
```bash
# ブラウザで確認
https://circlet.jp/.well-known/apple-app-site-association

# コマンドで確認
curl https://circlet.jp/.well-known/apple-app-site-association
```

**原因4: キャッシュの問題**
- アプリを削除して再インストール
- iOSデバイスを再起動

### Android App Linksが動作しない

**原因1: SHA256フィンガープリントが間違っている**
- assetlinks.jsonのSHA256を確認
- keystore署名で使用した証明書と一致しているか

**原因2: assetlinks.jsonにアクセスできない**
```bash
# ブラウザで確認
https://circlet.jp/.well-known/assetlinks.json

# コマンドで確認
curl https://circlet.jp/.well-known/assetlinks.json
```

**原因3: autoVerifyが失敗している**
```bash
# ADBで確認
adb shell pm get-app-links com.circlet.app
```

---

## 参考リンク

- [Apple Universal Links](https://developer.apple.com/ios/universal-links/)
- [Android App Links](https://developer.android.com/training/app-links)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [Apple Developer Program](https://developer.apple.com/programs/)

---

## まとめ

✅ **開発環境（現在）**
- カスタムURLスキーム `circlet://` で動作中
- Apple Developer Program登録不要

✅ **本番環境（将来）**
- Apple Developer Program登録（$99/年）
- apple-app-site-associationのTeam ID更新
- assetlinks.jsonのSHA256更新
- circle_service.dartでHTTPS URLに変更
- Firebase Hostingに再デプロイ

**切り替えタイミング:** App Storeリリース前
