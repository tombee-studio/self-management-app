# Layer 3: 検証インデックス

- **バージョン**: v1.0.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

## 共通検証条件

REQ・SPECの全9機能を対象とする。[検証運用](../operations/03_VERIFY.md)に従い、計画と実施結果を分ける。今回の作業はDDD＋契約駆動設計と計画の再確定。新契約の実装テスト・AWS接続・実機確認は未実施。

- 基準データ: 2026-11-01（JST）、日本円、未分類を含む標準9カテゴリ。各ケースで独立したSQLiteファイルまたはインメモリDBを使う。
- 時計と通知を注入可能とし、Undoはfake clockで4.999秒/5秒、通知は権限許可/拒否・再起動を検証する。
- タイムゾーンはAsia/Tokyo・UTC・America/New_YorkのDST境界を含める。日時の範囲と暦日計算を固定時計で検証する。
- iOS 16以降/Android 12以降のエミュレータ・代表実機、幅320/599/600/839/840/900論理pxで主要UIを確認する。Flutter/Dart・OS・実機型番は実行時の結果へ記録する。
- DB版1→2→3と版2→3の移行、旧削除キュー移行、初期シード、ロールバック、再起動、並列同期、部分失敗・再送・競合を含める。
- APIは隔離されたテスト環境で、遅延・タイムアウト・不正JSON・400/403/409/500と部分応答を注入する。個人の既存明細をテストで変更しない。
- 自動検査の基本は`flutter analyze`、`flutter test test/unit`、`flutter test test/widget test/widget_test.dart`。必要な追加テストを実装してから実行し、既存テストだけで計画の網羅を主張しない。
- インフラは`terraform -chdir=terraform init -backend=false`と`terraform -chdir=terraform validate`、専用環境のplanを確認する。apply・実環境費用測定の実施条件は結果に残す。

## 機能別検証計画

| 機能 | 計画 | 対応REQ | 対応SPEC | 必須ケース数 | 状態 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 日次支出ダッシュボード | [計画](features/daily-expense-dashboard.md) | [REQ](../req/features/daily-expense-dashboard.md) | [SPEC](../spec/features/daily-expense-dashboard.md) | 8 | done |
| 支出の手動登録・編集・削除 | [計画](features/manual-expense-crud.md) | [REQ](../req/features/manual-expense-crud.md) | [SPEC](../spec/features/manual-expense-crud.md) | 14 | done |
| 支出履歴・過去一覧 | [計画](features/expense-history-list.md) | [REQ](../req/features/expense-history-list.md) | [SPEC](../spec/features/expense-history-list.md) | 10 | done |
| 予算設定・管理 | [計画](features/budget-management.md) | [REQ](../req/features/budget-management.md) | [SPEC](../spec/features/budget-management.md) | 10 | done |
| カテゴリマスター管理 | [計画](features/category-master-management.md) | [REQ](../req/features/category-master-management.md) | [SPEC](../spec/features/category-master-management.md) | 10 | done |
| 外部決済イベント連携 | [計画](features/payment-event-ingestion.md) | [REQ](../req/features/payment-event-ingestion.md) | [SPEC](../spec/features/payment-event-ingestion.md) | 11 | done |
| クラウド同期 | [計画](features/aws-cloud-database-sync.md) | [REQ](../req/features/aws-cloud-database-sync.md) | [SPEC](../spec/features/aws-cloud-database-sync.md) | 16 | done |
| 共通UI・マルチデバイス対応 | [計画](features/cross-platform-shared-ui.md) | [REQ](../req/features/cross-platform-shared-ui.md) | [SPEC](../spec/features/cross-platform-shared-ui.md) | 9 | done |
| アプリアイコン・ブランディング | [計画](features/app-icon-branding.md) | [REQ](../req/features/app-icon-branding.md) | [SPEC](../spec/features/app-icon-branding.md) | 7 | done |

## 結果・証跡

全9機能とも未実施・結果文書未作成。実装前の結果文書は作らず、未実施をPASSにしない。実装・検証後に`results/<機能名>.md`を登録し、本一覧に対象コミット・実施判定・文書ステータスを追記する。

結果はケースID、期待値・実測値、PASS/FAIL/未実施、コミット、実施日時・環境・証跡、不具合と再検証を含める。全必須ケース合格と結果レビュー完了まで実装完了とは扱わない。既存自動テストは検証資産であり、対応ケースと結果が記録されるまでは合格の根拠にしない。

## 計画レビュー・移行ゲート

REQのACと各ケースを対応付け、正常・異常・境界・状態遷移、オフライン・再起動・画面適応・移行を含む。計画全件と本一覧がdoneなら実装開始ゲートを通過できる。結果は別工程であり、計画doneでも未実施のまま。文書間の整合レビューとコード差分は[STATUS](../STATUS.md)を参照する。

## 関連ADR

[ADR-0001: 全9機能の対象範囲](../adr/0001-nine-feature-scope.md)に従う。文書確定と実装・検証完了は別に判定する。

文書参照は現行REQ・SPEC・VERIFYを使用する。レガシー資料は削除済みであり、検証の正本として参照しない。

## ARCH-01共通検証

各機能のTC-CTに加え、以下6ケースを必須とする。参照は[共通アーキテクチャ](../spec/architecture.md)、[契約スキーマ](../spec/contracts/README.md)、[ADR-0002](../adr/0002-domain-contract-design.md)。

| ケースID | 前提・入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- |
| TC-ARCH-01 | Domain/Application/Infrastructure/Presentationのimport依存を検査し、Domainへdrift/Flutter、ApplicationへHTTP具象を混入したfixtureも検査 | 正しい依存は合格。禁止依存は違反パスとimportを示し失敗。DomainテストはFlutter binding不要 | アーキテクチャ静的テスト |
| TC-ARCH-02 | shared/events JSON SchemaとOpenAPIの参照を解決し、examples.jsonの正常/異常15ベクトルを検証。消した必須revisionと漏洩rawPayloadを入力 | 正常は適合、異常は拒否。全$ref解決。スキーマ構造の検証を意味検証済みとは扱わない | 文書契約/consumer fixture検査 |
| TC-ARCH-03 | 同じ契約fixtureをfake・SQLite provider・HTTP consumer/providerへ適用し、戻り型・エラー・再送・失敗を比較 | adapter間で型・事前/事後条件・副作用・冪等性の意味が一致。異なるエラー文字列やDB行型漏洩を拒否 | provider/consumer契約テスト |
| TC-ARCH-04 | Catalog版1のAを参照するExpense保存とRetireCategoryを並列実行。途中の配分削除で故障注入。次に同じcommandを再送 | 片側は最新版確認となるか原子的に整合して完了。存在しないカテゴリ参照0、金額不変、部分commit/重複イベント0 | Application/UoW結合 |
| TC-ARCH-05 | 版1と途中版2のDBをそれぞれ版3へ移行し再起動。Expense/Catalog/BudgetPlanへ集約版を初期化、途中失敗を注入 | 既存ID・金額・配分・キューを保持し各集約version=1。移行失敗は全体ロールバック。削除後の版も残り古い復元を拒否 | 移行結合 |
| TC-ARCH-06 | consumerが使う契約へ任意属性追加/必須属性追加/エラー意味変更を適用し、契約版と移行手順を比較 | 非互換は同じmajorに混入させず失敗。wire版2/内部イベント版1/DB版3を混同せず、provider先行・consumer切替順を検証 | 互換性/リリース契約テスト |

上のケースを含めた計画のdoneは計画レビューだけを示す。結果は対象コミット・実測・環境・証跡を記録して別途確定する。既存TCのID/受け入れ基準と過去の実行証跡を上書きしない。

計画件数: 既存61＋各機能の契約34＋共通ARCH6＝101必須ケース。機能別一覧は既存＋TC-CTの95件、共通ARCHは別表の6件。新契約のテスト結果は未実施。
