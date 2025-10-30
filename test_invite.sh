#!/bin/bash

# テスト用の招待ID
INVITE_ID="test-invite-123"

echo "=== Androidで招待リンクをテスト ==="
echo ""
echo "方法1: ADBコマンドでディープリンクを送信"
echo "adb shell am start -W -a android.intent.action.VIEW -d \"circlet://invite/$INVITE_ID\" com.circlet.app"
echo ""
echo "方法2: ブラウザでリンクを開く"
echo "Chrome等で以下のURLを開く："
echo "circlet://invite/$INVITE_ID"
echo ""
echo "方法3: HTTPS URL（App Links）"
echo "https://circlet.jp/invite/$INVITE_ID"
echo ""
