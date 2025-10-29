#!/bin/bash

# Circletアプリを簡単に起動するスクリプト

echo "🚀 Circletアプリを起動します..."
echo ""

# シミュレータを起動
echo "📱 iOSシミュレータを起動中..."
open -a Simulator

# シミュレータを明示的にブート
xcrun simctl boot EF2D2DBE-AAC5-4BE9-BE97-9697704ECB8E 2>/dev/null || true

# シミュレータが完全に起動するまで待機
echo "⏳ シミュレータの起動を待っています..."
until xcrun simctl list devices | grep "EF2D2DBE-AAC5-4BE9-BE97-9697704ECB8E" | grep "Booted" > /dev/null 2>&1; do
  sleep 1
done

echo "✅ シミュレータが起動しました"
echo ""

# Flutterアプリを実行
echo "🔥 Flutterアプリをビルド・実行中..."
export PATH="$HOME/flutter/bin:$PATH"
flutter run

echo ""
echo "✅ 完了！"
