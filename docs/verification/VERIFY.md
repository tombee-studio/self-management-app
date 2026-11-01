# Layer 3: 検証インデックス

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

## 共通条件

[REQ](../req/REQ.md)、[SPEC](../spec/SPEC.md)、[ADR-0003](../adr/0003-cloud-api-only.md)に従う。全9機能のACと契約を対象とする。計画doneは実施結果PASSではない。端末DB参照/移行/同期を検証対象から除き、HTTP consumer/providerとLambda/DynamoDBの保存・取得を確認する。

固定時計2026-11-01、Asia/Tokyoと夏時間地域、隔離owner、メモリUI状態、HTTP/通知fake、DynamoDBテスト環境を使う。実機はiOS16以降/Android12以降、代表幅320/600/900。

## 機能別計画

| 機能 | 計画 | ACケース | 契約ケース | 状態 |
| :--- | :--- | :--- | :--- | :--- |
| 支出の手動登録・編集・削除 | [計画](features/manual-expense-crud.md) | 9 | 5 | done |
| 外部決済イベント連携 | [計画](features/payment-event-ingestion.md) | 7 | 4 | done |
| クラウドデータアクセス | [計画](features/aws-cloud-database-sync.md) | 8 | 4 | done |
| カテゴリマスター管理 | [計画](features/category-master-management.md) | 6 | 4 | done |
| 日次支出ダッシュボード | [計画](features/daily-expense-dashboard.md) | 6 | 2 | done |
| 支出履歴・過去一覧 | [計画](features/expense-history-list.md) | 7 | 3 | done |
| アプリアイコン・ブランディング | [計画](features/app-icon-branding.md) | 4 | 3 | done |
| 予算設定・管理 | [計画](features/budget-management.md) | 7 | 3 | done |
| 共通UI・マルチデバイス対応 | [計画](features/cross-platform-shared-ui.md) | 6 | 3 | done |

## ARCH-02共通ケース

| ID | 対象 | 入力・手順 | 合否基準 |
| :--- | :--- | :--- | :--- |
| TC-R3-ARCH-01 | 依存方向 | アプリDB参照とDomainのAWS/Flutter/HTTP import違反fixtureを検査 | アプリの業務DB依存0。SDKはInfrastructureだけ。禁止importをパス付きで失敗にする |
| TC-R3-ARCH-02 | Schema/互換性 | 全$ref/oneOf/OpenAPIと15例、旧Push/Pull・版2・余分な属性を検査 | 正常適合・異常拒否。HTTP版3/イベント版2/操作版2を区別。全operationの入力と出力を検証 |
| TC-R3-ARCH-03 | 原子性/再送/CAS | 版1明細、同requestId再送/異入力、commit前障害/commit後応答喪失、2端末古い版 | 状態・版・世代・イベント・Receiptが全成功か全不変。同要求は元応答で増分0、異入力/古い版409 |
| TC-R3-ARCH-04 | カテゴリ廃止 | 1000明細を持つカテゴリ廃止と支出保存を並列実行、Budget更新中の障害を注入 | 有効カテゴリと配分が一体で切替。全画面/検索で未分類、金額不変。取引20項目/1MiB以内、Catalog/Plan150KiB超過413で不変 |
| TC-R3-ARCH-05 | Query世代/ページ | 121明細の2ページ目直前と一覧/合計間に別端末更新。token改変/別owner/別条件/期限切れ | 世代不一致409で先頭から再取得。50/50/21件、同世代で重複欠落0・全件合計一致。Queryの業務書込0 |
| TC-R3-ARCH-06 | 切替/通信なし | 再起動後通信なし、メモリ表示後切断、旧API書込停止と既存クラウド移行失敗 | オフライン保存/参照DBなし。直前表示未更新・入力保持。移行は件数/ID/総額保持、失敗でバックアップ復帰。端末DBの移送/消去を行わない |
| TC-R3-ARCH-07 | HTTP-Q01〜03 | GetExpense/GetCatalog/GetBudgetPlanの正常・未設定・削除済み・不正ownerと同fixtureでconsumer/provider比較 | ExpenseView/CatalogView/BudgetPlanView型一致、対象なし404、owner403、書込0。取得後編集で版を維持 |
| TC-R3-ARCH-08 | イベント/Undo | イベント版2と旧版1、配送再試行、削除応答喪失、UI4.9/5秒・受信29.9/30秒・使用済みGrant | 旧版を誤解釈しない。eventIdで重複副作用0。復元版一致、期限外410、同requestId再送はReceipt優先、元ID/金額保持 |

計画件数: AC 60＋機能契約 31＋共通 8＝99必須ケース。旧101ケースは旧設計の計画で、Git履歴に保持する。新計画の合格数へ加算しない。

## 結果・証跡

全9機能・共通ケースは未実施、結果文書未作成。実装後にresults/<機能名>.mdへケース別実測・対象・環境・証跡を記録する。既存自動テストや文書Schema検証だけで実装完了としない。[現状](../STATUS.md)を参照。

## 旧共通ケースとの対応

| 旧ID | 現行対応 |
| :--- | :--- |
| TC-ARCH-01 | TC-R3-ARCH-01 |
| TC-ARCH-02 | TC-R3-ARCH-02/08 |
| TC-ARCH-03 | TC-R3-ARCH-03/07と各TC-R3-CT |
| TC-ARCH-04 | TC-R3-ARCH-04 |
| TC-ARCH-05 | 端末DB移行は廃止。クラウド移行はTC-R3-ARCH-06 |
| TC-ARCH-06 | TC-R3-ARCH-02/06/08 |
