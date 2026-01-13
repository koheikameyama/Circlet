.PHONY: run sim clean help

# デフォルトのFlutterパス
FLUTTER := $(HOME)/flutter/bin/flutter

help: ## このヘルプを表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

run: ## シミュレータを起動してアプリを実行
	@echo "🚀 Circletアプリを起動します..."
	@open -a Simulator
	@echo "📱 シミュレータの起動を待っています..."
	@xcrun simctl boot EF2D2DBE-AAC5-4BE9-BE97-9697704ECB8E 2>/dev/null || true
	@until xcrun simctl list devices | grep "EF2D2DBE-AAC5-4BE9-BE97-9697704ECB8E" | grep "Booted" > /dev/null 2>&1; do \
		sleep 1; \
	done
	@echo "✅ シミュレータが起動しました"
	@echo "🔥 アプリをビルド・実行中..."
	@$(FLUTTER) run

sim: ## シミュレータのみ起動
	@echo "📱 iOSシミュレータを起動します..."
	@open -a Simulator

clean: ## ビルドキャッシュをクリア
	@echo "🧹 ビルドキャッシュをクリアします..."
	@$(FLUTTER) clean

devices: ## 利用可能なデバイスを表示
	@$(FLUTTER) devices

build: ## リリースビルドを作成
	@echo "🔨 リリースビルドを作成します..."
	@$(FLUTTER) build ios --release

web: ## Web版をローカルで起動（開発モード）
	@echo "🌐 Web版をChromeで起動します..."
	@$(FLUTTER) run -d chrome --web-port 8080

web-build: ## Web版をビルド
	@echo "📦 Web版をビルド中..."
	@$(FLUTTER) build web --release
	@echo "📄 静的ページをコピー中..."
	@cp web/landing.html build/web/
	@cp web/privacy.html build/web/
	@cp web/invite.html build/web/
	@cp -r web/assets build/web/ 2>/dev/null || true
	@echo "✅ ビルド完了！"

web-serve: ## ビルド済みWeb版をローカルサーバーで起動
	@echo "🔨 Web版をビルド中..."
	@make web-build
	@echo "🌐 ローカルサーバーを起動します..."
	@firebase serve --only hosting

web-deploy: ## Web版をFirebase Hostingにデプロイ
	@echo "🚀 Web版をデプロイします..."
	@make web-build
	@echo "📤 Firebase Hostingにアップロード中..."
	@firebase deploy --only hosting
	@echo "✅ デプロイ完了！"
	@echo "🔗 URL: https://circlet-9ee47.web.app"
