# Layer 2: 設計インデックス

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

## 適用範囲・共通アーキテクチャ

[REQ](../req/REQ.md)の全9機能を対象とする。端末はFlutter/RiverpodとHTTP Infrastructure、サーバーはAPI Gateway/Lambda/DynamoDB。業務データはAWS API経由で取得・保存し、端末内DBを置かない。保存成功はサーバー確定応答後だけ。DDDの業務モデルとRepositoryはサーバーに配置する。

## 共通の設計正本

[共通アーキテクチャ](architecture.md)にコンテキストマップ、用語・値型、集約境界、Port、UnitOfWork、契約の共通失敗/冪等性、依存方向を定める。[公開契約](contracts/README.md)にOpenAPI/JSON Schemaを置く。各機能は同じ既存文書へ再設計を集約し、機能を増やさない。DomainはFlutter/Riverpod/drift/HTTPへ依存しない。

| 機能 | モデルの種類 | 契約接頭辞 |
| :--- | :--- | :--- |
| 手動支出 | Expense集約 | MAN |
| 日次 | LedgerのReadModel | DASH |
| 履歴 | LedgerのReadModel | HIST |
| 予算 | BudgetPlan/Allocation | BUD |
| カテゴリ | CategoryCatalog/Category | CAT |
| 外部決済 | ACLと取り込みApplication | PAY |
| クラウドデータアクセス | CloudAccess/HTTP Port | SYN |
| 共通UI | 純粋Policy/UI状態 | UI |
| アイコン | AssetManifest/ビルド契約 | ICON |

## 機能別設計一覧

| 機能 | 設計 | 対応REQ | 状態 |
| :--- | :--- | :--- | :--- |
| 日次支出ダッシュボード | [daily-expense-dashboard](features/daily-expense-dashboard.md) | [REQ](../req/features/daily-expense-dashboard.md) | done |
| 支出の手動登録・編集・削除 | [manual-expense-crud](features/manual-expense-crud.md) | [REQ](../req/features/manual-expense-crud.md) | done |
| 支出履歴・過去一覧 | [expense-history-list](features/expense-history-list.md) | [REQ](../req/features/expense-history-list.md) | done |
| 予算設定・管理 | [budget-management](features/budget-management.md) | [REQ](../req/features/budget-management.md) | done |
| カテゴリマスター管理 | [category-master-management](features/category-master-management.md) | [REQ](../req/features/category-master-management.md) | done |
| 外部決済イベント連携 | [payment-event-ingestion](features/payment-event-ingestion.md) | [REQ](../req/features/payment-event-ingestion.md) | done |
| クラウドデータアクセス | [aws-cloud-database-sync](features/aws-cloud-database-sync.md) | [REQ](../req/features/aws-cloud-database-sync.md) | done |
| 共通UI・マルチデバイス対応 | [cross-platform-shared-ui](features/cross-platform-shared-ui.md) | [REQ](../req/features/cross-platform-shared-ui.md) | done |
| アプリアイコン・ブランディング | [app-icon-branding](features/app-icon-branding.md) | [REQ](../req/features/app-icon-branding.md) | done |

<a id="dynamodb-model"></a>
## 共通データモデル（DynamoDB）

保存形式はInfrastructure内部で、公開DTOと分離する。全テーブルのPKはownerId（user_id互換の変換は移行時だけ）。SKで項目を識別する。SDKの生項目をAPIへ返さない。

| テーブル | SKと主な内容 | 制約 |
| :--- | :--- | :--- |
| iris_expenses | expenseId、金額・カテゴリ参照・UTC日時・memo/memoSearch・支払い方法・source/externalTxId・version・isDeleted | 支出集約。削除後は版と元内容を保持 |
| iris_categories | catalog、有効Category集合・nameKey・sortOrder・廃止先対応・version | 集約内で名称一意。未分類保護。150KiB上限 |
| iris_budgets | current、設定・Allocation集合・version | 配分を集約内に保持。150KiB上限 |
| iris_metadata | generation、receipt#requestId、undo#token、external#source#txId、notification#period#threshold | owner世代CAS、冪等応答、期限/単回使用、外部ID一意、通知権利 |
| iris_domain_events | eventId、aggregateId/version・type・payload・occurredAt・deliveryState | 業務変更と同時に追記、配送済み重複排除 |

各CommandはTransactWriteItemsで状態・集約版・世代・Receipt・イベントを原子的に確定する。Queryのスナップショットは[共通アーキテクチャ](architecture.md#arch-storage)の世代検証で保証する。端末DB版・SyncOutbox・Replica用メタデータは設計から削除した。

## 共通ルール・画面

- JPY整数とgrapheme制約、指定timeZoneの暦日/暦月と家計期間を区別する。
- HTTP schemaVersion=3、操作契約v2.0.0、内部イベントschemaVersion=2。旧wire版2のPush/Pullは廃止。
- 保存/削除の確定後だけ成功表示し、関連画面をAPI再取得する。入力・直前表示はプロセスメモリのみ。
- 結果不明の保存は同じrequestIdで再送し、集約版競合は最新版確認へ誘導する。
- UIの600/840区分と8画面を維持。SCR-008は同期設定からクラウド接続設定へ変更する。
- [screens.drawio](screens.drawio)と各機能書に契約を対応付ける。

## 旧14項目の対応

| 旧項目 | 現行機能 | 集約理由 |
| :--- | :--- | :--- |
| budget-settings-navigation-ux | [予算](features/budget-management.md) | 予算画面の操作改善 |
| apple-pay-background-sync | [外部決済](features/payment-event-ingestion.md) | 決済取り込み経路 |
| aws-cloud-sync-builtin-endpoint | [同期](features/aws-cloud-database-sync.md) | 設定・トリガーの追加 |
| expense-deletion-sync-fix | [同期](features/aws-cloud-database-sync.md) | 削除のクラウド整合性 |
| multi-device-responsive-layout | [共通UI](features/cross-platform-shared-ui.md) | 共通画面のサイズ適応 |

他の旧9識別子は同名の現行機能へ対応する。レガシー資料・互換案内はownerの指示で削除した。旧版はGitコミット`9f30200`から参照できる。実装方式・スキーマ・画面の正本は本一覧の9機能に集約する。現在の[実装差分](../STATUS.md)は改修対象であり、設計の矛盾として扱わない。

## 関連ADR

[ADR-0001: 全9機能の対象範囲](../adr/0001-nine-feature-scope.md)に従う。文書確定と実装・検証完了は別に判定する。

## 設計方式のADR

[ADR-0002](../adr/0002-domain-contract-design.md)のDDD＋契約駆動方針を全9機能・共通DTO・イベントへ反映した。[ADR-0003](../adr/0003-cloud-api-only.md)により端末DBを廃止し、DynamoDB項目を公開DTOと分離する。
