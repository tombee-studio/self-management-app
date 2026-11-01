# Layer 3: 検証インデックス

- **バージョン**: v0.4.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

## 共通検証条件

REQ・SPECの全9機能を対象とする。[検証運用](../operations/03_VERIFY.md)に従い、計画と実施結果を分ける。今回の作業は文書の整合と検証計画の作成であり、アプリテスト・AWS接続・実機確認は未実施。

- 基準データ: 2026-11-01（JST）、日本円、未分類を含む標準9カテゴリ。各ケースで独立したSQLiteファイルまたはインメモリDBを使う。
- 時計と通知を注入可能とし、Undoはfake clockで4.999秒/5秒、通知は権限許可/拒否・再起動を検証する。
- タイムゾーンはAsia/Tokyo・UTC・America/New_YorkのDST境界を含める。日時の範囲と暦日計算を固定時計で検証する。
- iOS 16以降/Android 12以降のエミュレータ・代表実機、幅320/599/600/839/840/900論理pxで主要UIを確認する。Flutter/Dart・OS・実機型番は実行時の結果へ記録する。
- DB版1から2の移行、旧削除キュー移行、初期シード、ロールバック、再起動、並列同期、部分失敗・再送・競合を含める。
- APIは隔離されたテスト環境で、遅延・タイムアウト・不正JSON・400/403/409/500と部分応答を注入する。個人の既存明細をテストで変更しない。
- 自動検査の基本は`flutter analyze`、`flutter test test/unit`、`flutter test test/widget test/widget_test.dart`。必要な追加テストを実装してから実行し、既存テストだけで計画の網羅を主張しない。
- インフラは`terraform -chdir=terraform init -backend=false`と`terraform -chdir=terraform validate`、専用環境のplanを確認する。apply・実環境費用測定の実施条件は結果に残す。

## 機能別検証計画

| 機能 | 計画 | 対応REQ | 対応SPEC | 必須ケース数 | 状態 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 日次支出ダッシュボード | [計画](features/daily-expense-dashboard.md) | [REQ](../req/features/daily-expense-dashboard.md) | [SPEC](../spec/features/daily-expense-dashboard.md) | 6 | done |
| 支出の手動登録・編集・削除 | [計画](features/manual-expense-crud.md) | [REQ](../req/features/manual-expense-crud.md) | [SPEC](../spec/features/manual-expense-crud.md) | 9 | done |
| 支出履歴・過去一覧 | [計画](features/expense-history-list.md) | [REQ](../req/features/expense-history-list.md) | [SPEC](../spec/features/expense-history-list.md) | 7 | done |
| 予算設定・管理 | [計画](features/budget-management.md) | [REQ](../req/features/budget-management.md) | [SPEC](../spec/features/budget-management.md) | 7 | done |
| カテゴリマスター管理 | [計画](features/category-master-management.md) | [REQ](../req/features/category-master-management.md) | [SPEC](../spec/features/category-master-management.md) | 6 | done |
| 外部決済イベント連携 | [計画](features/payment-event-ingestion.md) | [REQ](../req/features/payment-event-ingestion.md) | [SPEC](../spec/features/payment-event-ingestion.md) | 7 | done |
| クラウド同期 | [計画](features/aws-cloud-database-sync.md) | [REQ](../req/features/aws-cloud-database-sync.md) | [SPEC](../spec/features/aws-cloud-database-sync.md) | 9 | done |
| 共通UI・マルチデバイス対応 | [計画](features/cross-platform-shared-ui.md) | [REQ](../req/features/cross-platform-shared-ui.md) | [SPEC](../spec/features/cross-platform-shared-ui.md) | 6 | done |
| アプリアイコン・ブランディング | [計画](features/app-icon-branding.md) | [REQ](../req/features/app-icon-branding.md) | [SPEC](../spec/features/app-icon-branding.md) | 4 | done |

## 結果・証跡

全9機能とも未実施・結果文書未作成。実装前の結果文書は作らず、未実施をPASSにしない。実装・検証後に`results/<機能名>.md`を登録し、本一覧に対象コミット・実施判定・文書ステータスを追記する。

結果はケースID、期待値・実測値、PASS/FAIL/未実施、コミット、実施日時・環境・証跡、不具合と再検証を含める。全必須ケース合格と結果レビュー完了まで実装完了とは扱わない。既存自動テストは検証資産であり、対応ケースと結果が記録されるまでは合格の根拠にしない。

## 計画レビュー・移行ゲート

REQのACと各ケースを対応付け、正常・異常・境界・状態遷移、オフライン・再起動・画面適応・移行を含む。計画全件と本一覧がdoneなら実装開始ゲートを通過できる。結果は別工程であり、計画doneでも未実施のまま。文書間の整合レビューとコード差分は[STATUS](../STATUS.md)を参照する。

## 関連ADR

[ADR-0001: 全9機能の対象範囲](../adr/0001-nine-feature-scope.md)に従う。文書確定と実装・検証完了は別に判定する。

文書参照は現行REQ・SPEC・VERIFYを使用する。レガシー資料は削除済みであり、検証の正本として参照しない。
