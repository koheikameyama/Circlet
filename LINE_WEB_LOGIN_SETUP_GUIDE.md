# Web版LINEログイン セットアップガイド

## 🎯 概要

このガイドでは、Web版でLINEログインを使えるようにするための設定手順を説明します。

## 📋 前提条件

- LINE Developers Consoleへのアクセス権限
- Firebase プロジェクトへのアクセス権限
- Firebase CLI がインストール済み

## ステップ1: LINE Developers Consoleでの設定

### 1.1 LINE Developers Consoleにアクセス

1. [LINE Developers Console](https://developers.line.biz/)にログイン
2. 既存のチャネル（Channel ID: `2008326126`）を選択

### 1.2 Callback URLを追加

1. **LINE Login** タブを開く
2. **Callback URL** セクションで以下のURLを追加：

```
https://circlet-9ee47.web.app
http://localhost:8080
```

※ `localhost:8080`は開発用です
※ **重要**: `/login` パスは含めません（ハッシュモードのため）

### 1.3 Channel Secretを取得

1. **Basic settings** タブを開く
2. **Channel secret** をコピーして保存（後で使用します）

## ステップ2: Firebase Functions の設定

### 2.1 LINE設定を追加

ターミナルで以下のコマンドを実行：

```bash
# LINE Channel IDを設定
firebase functions:config:set line.channel_id="2008326126"

# LINE Channel Secretを設定（YOUR_CHANNEL_SECRETを実際のChannel Secretに置き換える）
firebase functions:config:set line.channel_secret="YOUR_CHANNEL_SECRET"

# 設定を確認
firebase functions:config:get
```

### 2.2 Firebase Functionsをデプロイ

```bash
# Functionsをデプロイ
firebase deploy --only functions

# または全体をデプロイ
firebase deploy
```

## ステップ3: テスト

### 3.1 ローカルでテスト

```bash
# Web版をローカルで起動
make web
# または
npm run dev:web
```

ブラウザで `http://localhost:8080` にアクセスして、LINEログインボタンをクリック

### 3.2 本番環境でテスト

```bash
# Web版をビルド&デプロイ
make web-deploy
# または
npm run deploy:web
```

`https://circlet-9ee47.web.app` にアクセスして、LINEログインボタンをクリック

## 🔧 トラブルシューティング

### エラー: "LINE configuration not found"

**原因**: Firebase Functions の設定が正しく行われていない

**解決方法**:
```bash
firebase functions:config:get
```
で設定を確認し、必要に応じて再設定

### エラー: "Invalid redirect_uri"

**原因**: LINE Developers ConsoleにCallback URLが登録されていない

**解決方法**:
1. LINE Developers Consoleで Callback URLを確認
2. 以下のURLが登録されているか確認：
   - `https://circlet-9ee47.web.app/login`
   - `https://localhost:8080/login`

### エラー: "Authorization code not found"

**原因**: LINE Login の認証フローが正しく完了していない

**解決方法**:
1. ブラウザのコンソールでエラーを確認
2. LINEアプリでログインしているか確認
3. Callback URLが正しいか確認

## 📝 重要な注意事項

### セキュリティ

- **Channel Secret は絶対にクライアント側（Web）に置かない**
- Firebase Functions（サーバー側）でのみ使用
- GitHubなどにChannel Secretをコミットしない

### コスト

- Firebase Functions の無料枠：
  - 呼び出し：200万回/月
  - GB秒：40万/月

通常の使用では無料枠内で十分です

### モバイルアプリとの互換性

- モバイルアプリ：LINE SDK使用
- Web版：Firebase Functions経由でLINE Login

どちらも同じFirebase Authenticationユーザーとして管理されます

## ✅ デプロイ後の確認チェックリスト

- [ ] LINE Developers ConsoleにCallback URLを追加済み
- [ ] Firebase Functions の設定完了（`line.channel_id`と`line.channel_secret`）
- [ ] Firebase Functionsデプロイ完了
- [ ] Web版デプロイ完了
- [ ] ローカル環境でLINEログインテスト成功
- [ ] 本番環境でLINEログインテスト成功

## 🎉 完了！

これでWeb版でもLINEログインが使えるようになりました！

---

## 参考リンク

- [LINE Login Documentation](https://developers.line.biz/ja/docs/line-login/)
- [Firebase Functions Documentation](https://firebase.google.com/docs/functions)
- [Firebase Auth Custom Tokens](https://firebase.google.com/docs/auth/admin/create-custom-tokens)
