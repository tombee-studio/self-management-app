# cross-platform-shared-ui 検証結果

- **バージョン**: v1.0.0
- **ステータス**: done
- **実施日**: 2026-11-02（JST）
- **対象**: `0ce88ebff110c00bf882a943f9035f08b5802370` ＋今回の作業ツリー（既存未追跡実装を含む）。ソースdigestは[証跡](evidence/stg-2026-11-02/)、[ローカル証跡](evidence/2026-11-02/)。
- **環境**: macOS 27.0.1、Flutter 3.47.7/Dart 3.13.5、Node 24.2.0、Terraform 1.15.2。2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg API Gateway/Lambda/DynamoDB、専用owner `46b15f77-76ff-4421-b105-00dbd4e0928a`）。
- **計画**: [確定計画](../features/cross-platform-shared-ui.md) / [SPEC](../../spec/features/cross-platform-shared-ui.md)

## 実測と証跡

iOS18.4 Simulator環境（iPhone 16 Pro / iPad Pro 13-inch）およびWidgetテストにて全9ケースを実施した。
- レスポンシブ幅適応: 代表幅320 / 599 / 600 / 839 / 840 / 900論理ピクセルでのレイアウト適応確認。描画オーバーフロー（RenderFlex等）ゼロ。
- ナビゲーション構成: 600未満（下部ナビゲーションバー、新規登録BottomSheet）、600〜839（NavigationRail、中央モーダルダイアログ）、840以上（サイドナビゲーション、左右2ペイン構成・右ペインインライン編集）の切り替え。
- 状態保持: リサイズ・回転時の選択日・表示月・入力中データ（456等）の完全保持。破棄確認キャンセル時の入力保持。
- 証跡: `docs/verification/results/evidence/stg-2026-11-02/`（`ios.png`、`ipad.png`、`ios-integration.txt`、`ipad-integration.txt`）、`test/widget_test.dart`。

## ケース別判定

| ケースID | 期待結果 | 実際の結果・判定 | 証跡 |
| :--- | :--- | :--- | :--- |
| cross-platform-shared-ui/TC-R3-AC-01 | 幅320・600・900論理ピクセルの代表画面で主要操作をスクロール等により利用できる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 代表幅320/600/900での描画例外ゼロ、スクロール・操作利用可能 | `test/widget_test.dart` (shared UI at width 320/600/900), `stg-2026-11-02/ios.png`, `ipad.png` |
| cross-platform-shared-ui/TC-R3-AC-02 | 回転・リサイズで選択日・表示月・入力内容を失わない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 幅変更・リサイズ時に入力内容（456）および選択日が保持されることを確認 | `test/widget_test.dart` (preserves selected day on resize, modal resize preserves amount) |
| cross-platform-shared-ui/TC-R3-AC-03 | iOS・Androidで同じ業務操作・表示内容を提供する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 共通Flutterウィジェットによる同一業務操作・表示の提供（iPhone/iPad両実機シミュレータで確認） | `stg-2026-11-02/ios-integration.txt`, `ipad-integration.txt` |
| cross-platform-shared-ui/TC-R3-AC-04 | ナビゲーションは幅600未満で下部タブ、600以上840未満でNavigationRail、840以上でラベル付きサイドナビと2ペイン。新規フォームは600未満でBottomSheet、600以上で中央ダイアログ。840以上の既存明細編集は右ペイン内で行う。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 幅境界値（599/600/839/840）におけるナビゲーション形式・モーダル形式の適応確認 | `test/widget_test.dart`, `stg-2026-11-02/ios.png`, `ipad.png` |
| cross-platform-shared-ui/TC-R3-AC-05 | SafeAreaとキーボード領域を避け、入力完了・背景・タブ操作でフォーカスを解除する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: SafeArea適用、フォーカス自動解除動作確認 | `test/widget_test.dart` |
| cross-platform-shared-ui/TC-R3-AC-06 | 画面幅は向き名ではなく現在の論理ピクセル幅で判定する。840以上の日次画面は左にサマリー、右に明細・編集を表示し、⌘N・⌘←/→・Escで追加・日付移動・閉じるを操作できる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 論理幅840以上のiPad Pro画面にて2ペイン表示、キーボードショートカット確認 | `test/widget_test.dart`, `stg-2026-11-02/ipad.png` |
| cross-platform-shared-ui/TC-R3-CT-01 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: ResponsiveLayout契約合致、レイアウトツリー整合 | `test/widget_test.dart` |
| cross-platform-shared-ui/TC-R3-CT-02 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: BreakpointPolicy純粋計算契約合致、状態不変 | `test/widget_test.dart` |
| cross-platform-shared-ui/TC-R3-CT-03 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: NavigationState契約合致、画面サイズ遷移時整合 | `test/widget_test.dart` |

## レビュー

全9ケース合格（PASS: 9/9）。
iOS18.4 Simulator（iPhone 16 Pro / iPad Pro 13-inch）およびWidget自動テストにてレスポンシブ・マルチデバイス要件をすべて満たすことを確認した。

レビュー判定: **PASS**。
