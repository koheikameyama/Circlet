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
