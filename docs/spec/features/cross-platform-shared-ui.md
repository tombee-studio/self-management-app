# 共通UI・マルチデバイス対応 設計

- **バージョン**: v0.4.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/cross-platform-shared-ui.md)。設計の正本は本書。

## SPEC-01: 共通UI・サイズ区分

Flutter/Dart、Riverpod、Materialテーマを採用し、iOS/AndroidのUI・計算ロジックを共通化する。ネイティブ差分は通知・リンク・保存パスのアダプタへ限定する。日本語・JPY表示。最低OS版はiOS 16・Android 12。ビルド設定と実機検証対象をこの要求へ合わせる。

| 論理ピクセル幅 | ナビゲーション | 日次画面 | 支出フォーム |
| :--- | :--- | :--- | :--- |
| <600 | 下部タブ | 縦スクロール | BottomSheet |
| 600以上840未満 | NavigationRail | サマリー・内訳を横並び、明細は下 | 中央Dialog |
| 840以上 | ラベル付きサイドナビ | 左サマリー・右明細/編集の2ペイン | 新規はDialog、既存は右ペイン |

左ペインは幅の40%（最大380）、右は残り。Dialog最大幅460、利用可能高さに収め、内容はスクロール可能とする。幅はMediaQueryの現在幅で判定する。OS・端末名・縦横ラベルを閾値判定に使わない。900単独のナビ切替方式は採用しない。

## SPEC-02: 構成・状態

`MainNavigationShell`を`AdaptiveNavigationScaffold`とし、共通`WindowSizeClass.resolve(width)`で600/840を判定する。表示タブ・選択日・表示月・フォーム状態はRiverpodで保持し、レイアウト分岐の下にStatefulWidgetを作り直して失わない。全画面はSafeAreaとviewInsetsを考慮する。

⌘Nは手動支出追加、⌘←/→は日次の日付変更、Escはフォームを閉じる（未保存時は破棄確認）。テキスト入力中は矢印ショートカットを無効化する。背景・Done・タブ切替でFocusを解除する。画面幅320、600、840、900と各境界直前の表示を検証する。

## SPEC-03: エラー・理由

キーボードが表示されても保存・閉じるへスクロールして到達できること。大きな文字・金額で固定高さからはみ出さないようFlexible/Wrap/Scrollを使う。画面サイズによる表示だけを変え、金額や日付の業務ルールをOSごとに変えない。600/840の共通関数に集約し、ナビ・画面・図で異なる閾値を持たせない。

## REQ対応・検証入口

- [cross-platform-shared-ui/AC-01](../../req/features/cross-platform-shared-ui.md#ac-01): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-02](../../req/features/cross-platform-shared-ui.md#ac-02): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-03](../../req/features/cross-platform-shared-ui.md#ac-03): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-04](../../req/features/cross-platform-shared-ui.md#ac-04): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-05](../../req/features/cross-platform-shared-ui.md#ac-05): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-06](../../req/features/cross-platform-shared-ui.md#ac-06): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。
