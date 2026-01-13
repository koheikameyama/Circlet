#!/bin/bash

# Web版LINEログイン セットアップスクリプト

set -e

echo "🔧 Web版LINEログイン セットアップ"
echo "================================"
echo ""

# Channel Secretの入力を促す
echo "📝 LINE Developers Consoleから Channel Secret を取得してください"
echo "   URL: https://developers.line.biz/"
echo "   チャネル: 2008326126"
echo ""
read -p "LINE Channel Secret を入力してください: " CHANNEL_SECRET

if [ -z "$CHANNEL_SECRET" ]; then
  echo "❌ Channel Secret が入力されていません"
  exit 1
fi

echo ""
echo "⚙️  Firebase Functions に設定を追加しています..."

# Firebase Functions の設定
firebase functions:config:set line.channel_id="2008326126"
firebase functions:config:set line.channel_secret="$CHANNEL_SECRET"

echo ""
echo "✅ 設定が完了しました！"
echo ""
echo "📋 次のステップ:"
echo "1. LINE Developers ConsoleでCallback URLを追加:"
echo "   - https://circlet-9ee47.web.app"
echo "   - http://localhost:8080"
echo "   ※重要: /loginパスは含めません！"
echo ""
echo "2. Firebase Functionsをデプロイ:"
echo "   firebase deploy --only functions"
echo ""
echo "3. Web版をデプロイ:"
echo "   make web-deploy"
echo ""
echo "詳細は LINE_WEB_LOGIN_SETUP_GUIDE.md を参照してください"
