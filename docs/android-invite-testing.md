# Android招待リンクテストガイド

このドキュメントでは、Androidで招待リンクの動作を確認する方法を説明します。

## 前提条件

- Androidデバイスまたはエミュレータ
- Circletアプリがインストール済み
- ADB（Android Debug Bridge）がインストール済み（方法1の場合）

---

## テスト方法

### 方法1: ADBコマンドでテスト（推奨）

**最も確実な方法です。開発時のテストに最適。**

1. **デバイスをPCに接続**
   ```bash
   # デバイスが認識されているか確認
   adb devices
   ```

2. **アプリをインストール**
   ```bash
   flutter install
   ```

3. **招待リンクを送信**
   ```bash
   # カスタムURLスキーム版
   adb shell am start -W -a android.intent.action.VIEW \
     -d "circlet://invite/test-invite-123" \
     com.circlet.app
   
   # HTTPS URL版（App Links - 本番環境用）
   adb shell am start -W -a android.intent.action.VIEW \
     -d "https://circlet.jp/invite/test-invite-123" \
     com.circlet.app
   ```

4. **動作確認**
   - アプリが起動する
   - ログイン済み → 招待確認ダイアログが表示される
   - 未ログイン → ログイン画面へ遷移

---

### 方法2: ブラウザから開く

**実際のユーザー体験に近い方法です。**

1. **招待リンクを作成**
   - アプリ内でサークルの招待リンクを生成
   - 現在は `circlet://invite/{inviteId}` 形式

2. **リンクを自分に送信**
   - メールやメッセージアプリで自分に送信
   - または、ブラウザのアドレスバーに直接入力

3. **リンクをタップ**
   - Chromeなどのブラウザで開く
   - 「アプリで開く」ダイアログが表示される
   - 「Circlet」を選択

4. **動作確認**
   - アプリが起動し、招待処理が実行される

---

### 方法3: メッセージアプリでシェア

**最も実際のユースケースに近い方法です。**

1. **2台のAndroidデバイスを準備**
   - デバイスA: 招待を送る側
   - デバイスB: 招待を受ける側

2. **デバイスAで招待リンクを作成**
   - サークル画面 → 招待リンク作成
   - リンクをコピー

3. **デバイスBに送信**
   - LINE、メール、SMSなどで送信
   - または、メモアプリに貼り付けてシェア

4. **デバイスBで開く**
   - 受信したリンクをタップ
   - アプリが起動

---

## デバッグ方法

### Logcatでログを確認

```bash
# Circletアプリのログのみ表示
adb logcat | grep -i circlet

# ディープリンク関連のログのみ表示
adb logcat | grep -i "deep link"

# すべてのログをクリア
adb logcat -c
```

**期待されるログ出力:**
```
I/flutter (12345): Deep link received: circlet://invite/test-invite-123
I/flutter (12345): Invite link (custom scheme): test-invite-123
I/flutter (12345): Invite link received: test-invite-123
```

### Intent Filterの確認

```bash
# AndroidManifest.xmlのIntent Filterを確認
adb shell dumpsys package com.circlet.app | grep -A 10 "android.intent.action.VIEW"
```

**期待される出力:**
```
Action: "android.intent.action.VIEW"
Category: "android.intent.category.DEFAULT"
Category: "android.intent.category.BROWSABLE"
Scheme: "circlet"
Host: "invite"
```

---

## トラブルシューティング

### 問題1: リンクをタップしてもアプリが開かない

**原因:** Intent Filterが正しく設定されていない

**解決策:**
1. AndroidManifest.xmlを確認
   ```xml
   <intent-filter>
       <action android:name="android.intent.action.VIEW" />
       <category android:name="android.intent.category.DEFAULT" />
       <category android:name="android.intent.category.BROWSABLE" />
       <data
           android:scheme="circlet"
           android:host="invite" />
   </intent-filter>
   ```

2. アプリを再インストール
   ```bash
   flutter clean
   flutter build apk
   flutter install
   ```

### 問題2: アプリは開くが招待処理が実行されない

**原因:** DeepLinkServiceが初期化されていない

**解決策:**
1. Logcatでログを確認
   ```bash
   adb logcat | grep -i "deep link"
   ```

2. `lib/main.dart` の `_initDeepLinks()` が呼ばれているか確認

3. `lib/services/deep_link_service.dart` の `_handleDeepLink()` にブレークポイントを設定

### 問題3: HTTPS URLでアプリが開かない（App Links）

**原因:** assetlinks.jsonの設定が不正、またはSHA256フィンガープリントが一致していない

**解決策:**
1. assetlinks.jsonにアクセスできるか確認
   ```bash
   curl https://circlet.jp/.well-known/assetlinks.json
   ```

2. 署名証明書のSHA256を確認
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey \
     -storepass android \
     -keypass android | grep SHA256
   ```

3. App Linksの検証状態を確認
   ```bash
   adb shell pm get-app-links com.circlet.app
   ```

4. 検証を手動でトリガー
   ```bash
   adb shell pm verify-app-links --re-verify com.circlet.app
   ```

---

## サンプル招待フロー

### シナリオ1: ログイン済みユーザー

1. ユーザーAがサークル「テニス部」の招待リンクを作成
2. LINEでユーザーBに送信: `circlet://invite/abc123`
3. ユーザーBがリンクをタップ
4. Circletアプリが起動
5. ダイアログ表示: 「テニス部に参加しますか？」
6. 「参加する」をタップ
7. サークルに参加完了

### シナリオ2: 未ログインユーザー

1. ユーザーAがサークル「テニス部」の招待リンクを作成
2. メールでユーザーCに送信: `circlet://invite/abc123`
3. ユーザーCがリンクをタップ
4. Circletアプリが起動
5. ログイン画面が表示
6. LINEでログイン
7. 自動的にサークル参加処理が実行
8. サークル選択画面に「テニス部」が表示される

---

## まとめ

✅ **動作確認済み:**
- カスタムURLスキーム (`circlet://invite/{inviteId}`)
- ログイン済み/未ログインの両方のフロー
- アプリ起動時とアプリ実行中の両方

⏳ **準備完了（本番時に有効化）:**
- HTTPS URL (`https://circlet.jp/invite/{inviteId}`)
- App Links（assetlinks.jsonとSHA256の設定が必要）

**推奨テスト順序:**
1. ADBコマンドでカスタムURLスキームをテスト
2. ブラウザから開いてテスト
3. 実際のメッセージアプリでシェアしてテスト
