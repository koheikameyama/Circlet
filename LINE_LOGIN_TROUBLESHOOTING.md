# LINE Login トラブルシューティングガイド

## エラー: "Invalid redirect_uri value"

このエラーは、LINE Developers Consoleに登録されているCallback URLと、アプリから送信されるredirect_uriが一致しない場合に発生します。

## 🔍 Step 1: デバッグログを確認

1. ブラウザの開発者ツールを開く（F12キー）
2. Consoleタブを選択
3. LINEログインボタンをクリック
4. 以下のログを確認：
   - `LINE Login redirectUri: http://localhost:8080`
   - `LINE Login URL: https://access.line.me/oauth2/v2.1/authorize?...`

**このredirectUriの値をメモしてください**

## 🔧 Step 2: LINE Developers Consoleを確認

### 2.1 LINE Developers Consoleにアクセス

1. https://developers.line.biz/ にアクセス
2. ログイン
3. チャネルID `2008326126` を選択

### 2.2 Callback URLを確認・設定

1. **LINE Login** タブをクリック
2. **Callback URL** セクションまでスクロール
3. 以下の2つのURLが **正確に** 登録されているか確認：

```
http://localhost:8080
https://circlet-9ee47.web.app
```

### ⚠️ 重要な注意点

- [ ] URLの最後に `/` （スラッシュ）が **付いていない** ことを確認
- [ ] `http://` と `https://` のプロトコルが正確であることを確認
- [ ] ポート番号 `:8080` が含まれていることを確認（localhost用）
- [ ] `/login` や `/#/login` などのパスが **含まれていない** ことを確認

### 正しい例 ✅
```
http://localhost:8080
https://circlet-9ee47.web.app
```

### 間違った例 ❌
```
http://localhost:8080/           ← スラッシュが余計
http://localhost:8080/login      ← /loginが余計
http://localhost:8080/#/login    ← /#/loginが余計
https://circlet-9ee47.web.app/   ← スラッシュが余計
```

## 🔍 Step 3: 完全一致を確認

1. Step 1で確認した `redirectUri` の値
2. Step 2で確認した LINE Developers Console の Callback URL

この2つが **完全に一致** する必要があります。

例：
- アプリから送信: `http://localhost:8080`
- LINE Console: `http://localhost:8080`
→ ✅ 完全一致

- アプリから送信: `http://localhost:8080`
- LINE Console: `http://localhost:8080/`
→ ❌ 不一致（末尾のスラッシュ）

## 🔄 Step 4: 変更を保存して再テスト

1. LINE Developers Consoleで Callback URL を修正した場合、必ず **保存** ボタンをクリック
2. ブラウザをリフレッシュ（Ctrl+R または Cmd+R）
3. 開発者ツールのConsoleをクリア
4. 再度LINEログインボタンをクリック
5. エラーが解消されているか確認

## 🌐 Step 5: 本番環境でテスト

ローカル環境（localhost）で問題が続く場合、本番環境でテストしてみてください：

1. Web版をデプロイ：
   ```bash
   make web-deploy
   ```

2. ブラウザで https://circlet-9ee47.web.app にアクセス
3. LINEログインをテスト

本番環境で動作する場合、localhost固有の問題の可能性があります。

## 📝 よくある原因

### 1. URLの保存忘れ
LINE Developers Consoleで変更後、保存ボタンを押し忘れている

### 2. ブラウザキャッシュ
古いURLがキャッシュされている
→ 解決策: ハードリフレッシュ（Ctrl+Shift+R または Cmd+Shift+R）

### 3. 余計なパス
`/login` や `/#/` が含まれている
→ 解決策: ルートURLのみ登録（パスなし）

### 4. 末尾のスラッシュ
`http://localhost:8080/` のように末尾に `/` がある
→ 解決策: スラッシュを削除

### 5. プロトコルの違い
`http` と `https` が混在している
→ 解決策: localhost は `http`、本番は `https`

### 6. ポート番号の有無
localhost でポート番号を指定していない
→ 解決策: `:8080` を含める

## 🆘 それでも解決しない場合

1. デバッグログのスクリーンショットを送る
   - Console に表示される `LINE Login redirectUri` の値
   - LINE Developers Console の Callback URL 設定画面

2. 試してみる別の方法：
   - 別のブラウザでテスト（Chrome, Firefox, Safari）
   - シークレットモード/プライベートブラウジングでテスト
   - Firebase Functions のログを確認:
     ```bash
     firebase functions:log
     ```

3. LINE Channel の設定を再確認：
   - チャネルが有効になっているか
   - LINE Login が有効になっているか
   - Web app タイプが選択されているか

## 📞 サポート情報

- LINE Developers ドキュメント: https://developers.line.biz/ja/docs/line-login/
- Firebase Functions ログ: `firebase functions:log`
- アプリログ: ブラウザの開発者ツール Console タブ
