# Circlet Webサイト

## 📱 公開URL

### 本番環境（予定）
- **トップページ**: https://circlet.jp/
- **プライバシーポリシー**: https://circlet.jp/privacy.html
- **招待ページ**: https://circlet.jp/invite/[inviteId]

### 開発環境（現在）
- **トップページ**: https://circlet-9ee47.web.app/
- **プライバシーポリシー**: https://circlet-9ee47.web.app/privacy.html
- **招待ページ**: https://circlet-9ee47.web.app/invite/[inviteId]

## 📂 ディレクトリ構成

```
Circlet/
├── web/                  # Firebase Hosting公開ディレクトリ
│   ├── index.html       # トップページ（アプリ紹介）
│   ├── privacy.html     # プライバシーポリシー
│   ├── invite.html      # 招待ページ
│   ├── assets/
│   │   ├── css/
│   │   │   └── style.css    # スタイルシート
│   │   ├── js/
│   │   │   └── common.js    # 共通ヘッダー・フッター
│   │   └── images/
│   │       ├── logo.jpeg        # サービスロゴ
│   │       ├── ui.jpg           # アプリUI画像
│   │       ├── apple_store.svg  # App Storeバッジ
│   │       └── google_play.png  # Google Playバッジ
│   └── .well-known/     # Universal Links・App Links設定
└── firebase.json        # Firebase Hosting設定
```

## 🎨 ページ構成

### 1. トップページ (index.html)
- **ヒーローセクション**: キャッチコピー、ダウンロードボタン
- **機能紹介**: 6つの主要機能をカード形式で表示
- **ユースケース**: 4種類のサークル向け紹介
- **ダウンロードセクション**: App Store / Google Playボタン
- **フッター**: リンク、お問い合わせ

### 2. プライバシーポリシー (privacy.html)
以下の項目を含む包括的なプライバシーポリシー：
- 収集する情報
- 情報の利用目的
- 情報の共有と第三者提供
- 情報の保護
- データの保存期間
- ユーザーの権利
- 子どもの個人情報
- Cookieおよびトラッキング技術
- プライバシーポリシーの変更
- お問い合わせ

### 3. 招待ページ (invite.html)
- 招待リンク専用ページ
- デバイス検出とアプリ自動起動
- App Store / Google Playへのフォールバック

## 🔧 更新方法

### Webサイトのコンテンツを編集

1. **ファイルを直接編集**
   ```bash
   # アプリ紹介ページを編集
   code web/index.html

   # プライバシーポリシーを編集
   code web/privacy.html

   # CSSを編集
   code web/assets/css/style.css

   # 共通ヘッダー・フッターを編集
   code web/assets/js/common.js
   ```

2. **デプロイ**
   ```bash
   # Firebase Hostingにデプロイ
   npm run deploy:website
   ```

### カスタムドメイン設定後

カスタムドメイン `circlet.jp` を設定後、以下のURLが有効になります：

- https://circlet.jp/ → トップページ
- https://circlet.jp/privacy.html → プライバシーポリシー
- https://circlet.jp/invite/[inviteId] → 招待ページ

## 📝 App Store / Google Playリンクの更新

アプリ公開後、以下のファイルを編集してストアリンクを更新してください：

**web/index.html** (2箇所)
```html
<!-- App Storeリンク -->
<a href="YOUR_APP_STORE_URL" class="store-button app-store">

<!-- Google Playリンク -->
<a href="YOUR_GOOGLE_PLAY_URL" class="store-button google-play">
```

更新後、デプロイを忘れずに：
```bash
npm run deploy:website
```

## 🎯 SEO最適化

各ページには以下のメタタグが設定されています：

### 基本メタタグ
```html
<meta name="description" content="...">
<meta name="keywords" content="...">
<meta name="author" content="Circlet">
<meta name="robots" content="index, follow">
```

### Open Graphタグ（Facebook、LINE等のSNSシェア用）
```html
<meta property="og:type" content="website">
<meta property="og:url" content="https://circlet.jp/">
<meta property="og:title" content="Circlet - サークル管理アプリ">
<meta property="og:description" content="...">
<meta property="og:image" content="https://circlet.jp/assets/images/ui.jpg">
<meta property="og:site_name" content="Circlet">
<meta property="og:locale" content="ja_JP">
```

### Twitterカード
```html
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="...">
<meta name="twitter:description" content="...">
<meta name="twitter:image" content="...">
```

### その他
- ファビコン: `assets/images/logo.jpeg`
- テーマカラー: `#0476b9`（ブラウザのアドレスバーの色）

### 今後の追加検討
- サイトマップ（sitemap.xml）
- Google Analytics

## 📱 レスポンシブデザイン

Webサイトはモバイル、タブレット、デスクトップに対応：
- モバイルファースト設計
- ブレークポイント: 768px
- タッチフレンドリーなUI
- 読みやすいフォントサイズ

## ⚠️ 注意事項

1. **プライバシーポリシーURL**
   - App Store / Google Playの申請時に必要
   - URL: `https://circlet.jp/privacy.html`

2. **メールアドレス**
   - サポートメールは `support@circlet.jp` を想定
   - 実際のメールアドレスに変更してください

3. **著作権表記**
   - フッターの年号を適宜更新

4. **画像**
   - 実際のアプリスクリーンショットに差し替え推奨
   - `web/assets/images/` に配置

## 🚀 公開後のチェックリスト

- [ ] カスタムドメイン `circlet.jp` の設定完了
- [ ] App Store / Google Playリンクの更新
- [ ] サポートメールアドレスの確認
- [ ] 実際のスクリーンショット追加
- [ ] モバイルでの表示確認
- [ ] 各リンクの動作確認
- [ ] プライバシーポリシーの法務レビュー
- [ ] Google Analytics等のアナリティクス設定（任意）

## 📧 お問い合わせ

Webサイトに関する質問や問題があれば、プロジェクトのIssuesで報告してください。
