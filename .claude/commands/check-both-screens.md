# Check Both Screens

UI変更時に管理者画面とメンバー画面の両方をチェックしてください。

## チェック対象

1. **イベント関連の変更**:
   - `lib/screens/admin/admin_home_screen.dart` (管理者側)
   - `lib/screens/participant/participant_home_screen.dart` (メンバー側)

2. **イベント詳細画面の変更**:
   - `lib/screens/admin/admin_event_detail_screen.dart` (管理者側)
   - `lib/screens/participant/participant_event_detail_screen.dart` (メンバー側)

3. **参加者一覧画面の変更**:
   - `lib/screens/admin/admin_event_participants_screen.dart` (管理者側)
   - `lib/screens/participant/participant_event_participants_screen.dart` (メンバー側)

## チェック手順

1. 最近変更したファイルを確認
2. そのファイルが管理者側（admin）かメンバー側（participant）かを判定
3. 同じ機能を持つ対応する画面を検索
4. 両方に同じ変更が必要かを確認
5. 必要であれば両方を修正

## 注意事項

- UIの変更（レイアウト、スタイル、バッジ表示など）は両画面で統一すること
- ビジネスロジックの違い（権限チェック、操作可否など）は画面ごとに異なる場合がある
- 両画面で同じコンポーネントを使っていないか確認（共通化できる場合は検討）
