#!/bin/bash

# Flutter Webアプリのビルドとデプロイスクリプト

set -e

echo "🚀 Flutter Webアプリのビルドとデプロイを開始します..."

# 1. Webアプリをビルド
echo "📦 Flutter Webアプリをビルド中..."
flutter build web --release

# 2. 静的ページをコピー
echo "📄 静的ページをコピー中..."
cp web/landing.html build/web/
cp web/privacy.html build/web/
cp web/invite.html build/web/

# 3. アセットをコピー（必要に応じて）
echo "🎨 アセットをコピー中..."
cp -r web/assets build/web/ 2>/dev/null || true

# 4. Firebase Hostingにデプロイ
echo "🌐 Firebase Hostingにデプロイ中..."
firebase deploy --only hosting

echo "✅ デプロイが完了しました！"
echo "🔗 URL: https://circlet-9ee47.web.app"
