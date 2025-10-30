#!/bin/bash

echo "=== ドメイン変更確認スクリプト ==="
echo ""
echo "変更前: circlet-9ee47.web.app"
echo "変更後: circlet.jp"
echo ""

echo "【確認中...】"
echo ""

# circlet-9ee47.web.app が残っていないか確認
echo "1. 古いドメインの残存チェック:"
if grep -r "circlet-9ee47\.web\.app" lib/ android/ ios/ docs/ web/ --exclude-dir=.git --exclude-dir=build 2>/dev/null; then
    echo "⚠️  警告: 古いドメインが見つかりました"
else
    echo "✅ OK: 古いドメインは見つかりませんでした"
fi

echo ""
echo "2. 新しいドメインの確認:"
if grep -r "circlet\.jp" lib/ android/ ios/ docs/ web/ --exclude-dir=.git --exclude-dir=build 2>/dev/null | head -5; then
    echo "✅ OK: 新しいドメインが設定されています"
else
    echo "⚠️  警告: 新しいドメインが見つかりません"
fi

echo ""
echo "=== 確認完了 ==="
