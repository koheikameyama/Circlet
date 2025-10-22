# Google Maps API セットアップガイド

## 概要
このアプリでは、イベントの場所入力時にGoogle Places Autocomplete機能を使用しています。
この機能を使用するには、Google Cloud ConsoleでAPIキーを取得する必要があります。

## セットアップ手順

### 1. Google Cloud Consoleにアクセス
https://console.cloud.google.com/ にアクセスしてログインします。

### 2. プロジェクトの作成（または既存プロジェクトを選択）
- 画面上部のプロジェクト選択ドロップダウンをクリック
- 「新しいプロジェクト」をクリック
- プロジェクト名を入力（例: grumane-app）
- 「作成」をクリック

### 3. Places APIを有効化
1. 左側メニューから「APIとサービス」→「ライブラリ」を選択
2. 検索バーで「Places API」を検索
3. 「Places API」をクリック
4. 「有効にする」ボタンをクリック

### 4. APIキーの作成
1. 左側メニューから「APIとサービス」→「認証情報」を選択
2. 上部の「認証情報を作成」をクリック
3. 「APIキー」を選択
4. 作成されたAPIキーをコピー

### 5. APIキーの制限設定（推奨）
セキュリティのため、APIキーに制限を設定することを推奨します：

1. 作成したAPIキーの右側にある編集アイコン（鉛筆）をクリック
2. 「アプリケーションの制限」セクションで適切な制限を選択
   - iOSアプリの場合: 「iOSアプリ」を選択し、バンドルIDを入力
   - Androidアプリの場合: 「Androidアプリ」を選択し、パッケージ名とSHA-1証明書フィンガープリントを入力
3. 「APIの制限」セクションで「キーを制限」を選択
4. 「Places API」にチェックを入れる
5. 「保存」をクリック

### 6. アプリへのAPIキーの設定
1. `lib/config/api_keys.dart` ファイルを開く
2. `googlePlacesApiKey` の値を、コピーしたAPIキーに置き換える

```dart
class ApiKeys {
  static const String googlePlacesApiKey = 'ここにAPIキーを貼り付け';
}
```

### 7. 動作確認
1. アプリを再起動
2. イベント作成画面で場所フィールドに文字を入力
3. 候補が表示されれば成功！

## 注意事項

- APIキーは公開しないでください
- `api_keys.dart`ファイルを`.gitignore`に追加することを推奨します
- Google Places APIは無料枠がありますが、使用量によっては課金される可能性があります
- 詳細は Google Cloud の料金ページを確認してください: https://cloud.google.com/maps-platform/pricing

## トラブルシューティング

### 候補が表示されない場合
1. APIキーが正しく設定されているか確認
2. Places APIが有効化されているか確認
3. インターネット接続を確認
4. Google Cloud Consoleで請求先アカウントが設定されているか確認

### エラーが表示される場合
- APIキーの制限設定を確認
- Google Cloud Consoleの「APIとサービス」→「ダッシュボード」でAPIの使用状況を確認
- ログを確認してエラーメッセージを確認

## サポート
問題が解決しない場合は、Google Maps Platform のドキュメントを参照してください:
https://developers.google.com/maps/documentation/places/web-service
