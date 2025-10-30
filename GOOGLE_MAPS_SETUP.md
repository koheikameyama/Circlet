# Google Maps API セットアップガイド

## 概要

このアプリでは、イベントの場所入力時に Google Places Autocomplete 機能を使用しています。
この機能を使用するには、Google Cloud Console で API キーを取得する必要があります。

## セットアップ手順

### 1. Google Cloud Console にアクセス

https://console.cloud.google.com/ にアクセスしてログインします。

### 2. プロジェクトの作成（または既存プロジェクトを選択）

- 画面上部のプロジェクト選択ドロップダウンをクリック
- 「新しいプロジェクト」をクリック
- プロジェクト名を入力（例: Circlet-app）
- 「作成」をクリック

### 3. Places API を有効化

1. 左側メニューから「API とサービス」→「ライブラリ」を選択
2. 検索バーで「Places API」を検索
3. 「Places API」をクリック
4. 「有効にする」ボタンをクリック

### 4. API キーの作成

1. 左側メニューから「API とサービス」→「認証情報」を選択
2. 上部の「認証情報を作成」をクリック
3. 「API キー」を選択
4. 作成された API キーをコピー

### 5. API キーの制限設定（推奨）

セキュリティのため、API キーに制限を設定することを推奨します：

1. 作成した API キーの右側にある編集アイコン（鉛筆）をクリック
2. 「アプリケーションの制限」セクションで適切な制限を選択
   - iOS アプリの場合: 「iOS アプリ」を選択し、バンドル ID を入力
   - Android アプリの場合: 「Android アプリ」を選択し、パッケージ名と SHA-1 証明書フィンガープリントを入力
3. 「API の制限」セクションで「キーを制限」を選択
4. 「Places API」にチェックを入れる
5. 「保存」をクリック

### 6. アプリへの API キーの設定

1. `lib/config/api_keys.dart` ファイルを開く
2. `googlePlacesApiKey` の値を、コピーした API キーに置き換える

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

- API キーは公開しないでください
- `api_keys.dart`ファイルを`.gitignore`に追加することを推奨します
- Google Places API は無料枠がありますが、使用量によっては課金される可能性があります
- 詳細は Google Cloud の料金ページを確認してください: https://cloud.google.com/maps-platform/pricing

## トラブルシューティング

### 候補が表示されない場合

1. API キーが正しく設定されているか確認
2. Places API が有効化されているか確認
3. インターネット接続を確認
4. Google Cloud Console で請求先アカウントが設定されているか確認

### エラーが表示される場合

- API キーの制限設定を確認
- Google Cloud Console の「API とサービス」→「ダッシュボード」で API の使用状況を確認
- ログを確認してエラーメッセージを確認

## サポート

問題が解決しない場合は、Google Maps Platform のドキュメントを参照してください:
https://developers.google.com/maps/documentation/places/web-service
