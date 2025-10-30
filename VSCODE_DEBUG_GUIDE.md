# VSCode デバッグガイド

このガイドでは、VSCode で Circlet アプリをデバッグする方法を説明します。

## 前提条件

1. **Flutter SDK** がインストールされている
2. **VSCode** に以下の拡張機能がインストールされている:
   - Flutter (Dart-Code.flutter)
   - Dart (Dart-Code.dart-code)
3. **エミュレータ/シミュレータ** が起動している

## エミュレータ/シミュレータの起動

### iOS シミュレータの起動

```bash
# 利用可能なシミュレータを確認
xcrun simctl list devices

# シミュレータを起動（例: iPhone 15 Pro）
open -a Simulator
```

または、VSCode から:

1. `Cmd + Shift + P` (Mac の場合)
2. 「Flutter: Select Device」を選択
3. iOS シミュレータを選択

### Android エミュレータの起動

```bash
# 利用可能なエミュレータを確認
emulator -list-avds

# エミュレータを起動
emulator -avd <エミュレータ名>
```

または、Android Studio から起動

## VSCode でのデバッグ方法

### 方法 1: デバッグパネルから起動

1. VSCode でプロジェクトを開く
2. 左サイドバーの「実行とデバッグ」アイコンをクリック（虫アイコン）
3. 上部のドロップダウンから起動設定を選択:
   - **Debug (iOS Simulator)**: iOS シミュレータでデバッグ
   - **Debug (Android Emulator)**: Android エミュレータでデバッグ
4. 緑の再生ボタン（▶）をクリック、または `F5` を押す

### 方法 2: ショートカットキー

- `F5`: デバッグ開始
- `Shift + F5`: デバッグ停止
- `Cmd + Shift + F5` / `Ctrl + Shift + F5`: デバッグ再起動
- `F10`: ステップオーバー
- `F11`: ステップイン
- `Shift + F11`: ステップアウト

### 方法 3: コードエディタから直接実行

1. `lib/main.dart` を開く
2. エディタ右上の「Run」または「Debug」ボタンをクリック

## ブレークポイントの設定

1. ブレークポイントを設定したい行番号の左側をクリック
2. 赤い点が表示されます
3. デバッグ実行すると、その行で実行が一時停止します

### 便利なブレークポイント

```dart
// 例: ログインボタンが押された時
void _handleLineLogin() async {
  // ← ここにブレークポイント
  setState(() {
    _isLoading = true;
  });
  // ...
}
```

## Firebase Emulator の使用

### Emulator のセットアップ

```bash
# Firebase CLIのインストール（未インストールの場合）
npm install -g firebase-tools

# Firebaseにログイン
firebase login

# Firebaseプロジェクトを初期化（初回のみ）
firebase init emulators
```

### Emulator の起動

```bash
# プロジェクトディレクトリで実行
firebase emulators:start
```

これにより以下のサービスが起動します:

- **Authentication**: http://localhost:9099
- **Firestore**: http://localhost:8080
- **Storage**: http://localhost:9199
- **Emulator UI**: http://localhost:4000

### Emulator UI の使い方

1. ブラウザで http://localhost:4000 を開く
2. 以下を確認・操作できます:
   - **Authentication**: ユーザー一覧、手動でユーザー追加
   - **Firestore**: データベース内容の確認・編集
   - **Storage**: アップロードされたファイルの確認

### デバッグモードでの動作

アプリを**デバッグモード**で起動すると、自動的に Firebase Emulator に接続します。

- `lib/config/firebase_emulator_config.dart` で制御
- デバッグビルドの場合のみ Emulator に接続
- リリースビルドは本番 Firebase に接続

## ホットリロード

コードを変更した後、アプリを再起動せずに変更を反映できます:

- `r`: ホットリロード（ウィジェットの再ビルド）
- `R`: ホットリスタート（アプリの完全再起動）

または、VSCode の場合:

- 保存（`Cmd + S` / `Ctrl + S`）すると自動的にホットリロードされます

## デバッグコンソールの使用

### print 文によるログ出力

```dart
print('デバッグ: ユーザーID = $userId');
```

### debugPrint（長い文字列用）

```dart
debugPrint('非常に長い文字列...');
```

### ログレベル

```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('デバッグモードでのみ表示');
}
```

## 変数の監視

デバッグ中に変数の値を確認:

1. 左サイドバーの「変数」セクションで現在の変数を確認
2. 「ウォッチ」セクションで特定の式を監視
3. ホバーして変数の値を確認

## パフォーマンスプロファイリング

### Profile モードで起動

1. デバッグパネルで「Profile (iOS)」または「Profile (Android)」を選択
2. Flutter DevTools が自動的に開きます
3. パフォーマンスの問題を分析

### DevTools の起動

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub global activate devtools
flutter pub global run devtools
```

## トラブルシューティング

### エミュレータが見つからない

```bash
# デバイスを確認
export PATH="$HOME/flutter/bin:$PATH"
flutter devices
```

出力がない場合:

- iOS: Xcode でシミュレータを起動
- Android: Android Studio で AVD を起動

### ホットリロードが動作しない

- `Cmd + Shift + P` → 「Flutter: Hot Reload」を実行
- それでも動作しない場合は「Flutter: Hot Restart」

### Firebase Emulator 接続エラー

1. Emulator が起動しているか確認:

```bash
firebase emulators:start
```

2. ポートが使用されていないか確認:

```bash
lsof -i :8080
lsof -i :9099
```

### ビルドエラー

```bash
# クリーンビルド
export PATH="$HOME/flutter/bin:$PATH"
flutter clean
flutter pub get
flutter run
```

## 便利な VSCode コマンド

`Cmd + Shift + P` (Mac) / `Ctrl + Shift + P` (Windows/Linux) で以下を実行:

- `Flutter: New Project`: 新規プロジェクト作成
- `Flutter: Select Device`: デバイス選択
- `Flutter: Hot Reload`: ホットリロード
- `Flutter: Hot Restart`: ホットリスタート
- `Flutter: Open DevTools`: DevTools を開く
- `Flutter: Clean Project`: プロジェクトをクリーン
- `Dart: Add Dependency`: パッケージを追加

## 推奨ワークフロー

1. **Firebase Emulator を起動**

```bash
firebase emulators:start
```

2. **エミュレータ/シミュレータを起動**

```bash
# iOS
open -a Simulator

# Android
emulator -avd <エミュレータ名>
```

3. **VSCode でデバッグ開始**

   - `F5` を押すか、デバッグパネルから起動

4. **コード編集 & ホットリロード**

   - コードを編集して保存（自動でホットリロード）

5. **Emulator UI でデータ確認**
   - http://localhost:4000 でデータベース内容を確認

## さらに詳しく

- [Flutter 公式ドキュメント - デバッグ](https://docs.flutter.dev/testing/debugging)
- [VSCode Flutter 拡張機能](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
