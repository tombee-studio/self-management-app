# Layer 2: 設計インデックス

- **バージョン**: v0.4.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

## 適用範囲・共通アーキテクチャ

[REQ](../req/REQ.md)の全9機能を対象とし、Flutterのfeature単位でpresentation/domain/dataを分離する。UIはRiverpod、永続化はdrift/SQLite、クラウドはHTTP API・Lambda・DynamoDBとTerraformを用いる。型安全なローカルStreamと端末内保存を基本とし、クラウド通信の完了をUI保存の前提にしない。OS差分は通知・リンク・保存先のアダプタに閉じ込める。

## 機能別設計一覧

| 機能 | 設計 | 対応REQ | 状態 |
| :--- | :--- | :--- | :--- |
| 日次支出ダッシュボード | [daily-expense-dashboard](features/daily-expense-dashboard.md) | [REQ](../req/features/daily-expense-dashboard.md) | done |
| 支出の手動登録・編集・削除 | [manual-expense-crud](features/manual-expense-crud.md) | [REQ](../req/features/manual-expense-crud.md) | done |
| 支出履歴・過去一覧 | [expense-history-list](features/expense-history-list.md) | [REQ](../req/features/expense-history-list.md) | done |
| 予算設定・管理 | [budget-management](features/budget-management.md) | [REQ](../req/features/budget-management.md) | done |
| カテゴリマスター管理 | [category-master-management](features/category-master-management.md) | [REQ](../req/features/category-master-management.md) | done |
| 外部決済イベント連携 | [payment-event-ingestion](features/payment-event-ingestion.md) | [REQ](../req/features/payment-event-ingestion.md) | done |
| クラウド同期 | [aws-cloud-database-sync](features/aws-cloud-database-sync.md) | [REQ](../req/features/aws-cloud-database-sync.md) | done |
| 共通UI・マルチデバイス対応 | [cross-platform-shared-ui](features/cross-platform-shared-ui.md) | [REQ](../req/features/cross-platform-shared-ui.md) | done |
| アプリアイコン・ブランディング | [app-icon-branding](features/app-icon-branding.md) | [REQ](../req/features/app-icon-branding.md) | done |

## 共通データモデル（目標スキーマ版2）

現行コードのschemaVersion=1から移行する目標設計。下記がDB上の正本であり、過去資料のローカルis_synced/is_deleted列は使用しない。

| テーブル | 主キー・主な列 | 制約 |
| :--- | :--- | :--- |
| Categories | id,name,nameKey,iconKey,colorHex,sortOrder,isSystem,createdAt,updatedAt | nameKey一意。未分類を保護 |
| Expenses | id,amount,categoryId,spentAt,memo,memoSearch,paymentMethod,source,externalTxId,createdAt,updatedAt | amount 1〜99,999,999、カテゴリ参照、source+externalTxIdはNULL以外一意 |
| Budgets | id,monthlyAmount,startDay,isCategoryBudgetEnabled,isAlertNotificationEnabled,updatedAt | id=1の1件。開始日1〜28 |
| CategoryBudgets | categoryId,allocatedAmount,updatedAt | categoryId参照。0円以上 |
| SyncOutbox | entityType+entityId,operation,payloadJson,updatedAt,revision | 本体変更と同一トランザクション。送信時revisionでack |
| NotificationHistory | periodStart+threshold,notifiedAt | 予算通知の重複防止 |

日時はUTCのミリ秒精度で保持・通信する。表示・日次/月次の境界は端末ローカルの暦日で計算してUTC範囲へ変換する。範囲は開始以上・次の境界未満とする。カテゴリ参照を必須とし、未分類を起動・移行時に冪等生成する。外部店舗名はmemoへ保存し、sourceとpaymentMethodを分離する。検索用memoSearchはNFKC・lowercase・trimを適用する。

### 移行

onUpgradeで版1から列・新テーブル・インデックスを追加し、既存メモ・名称の正規化値を埋める。既存ID・支出・配分・予算を保持する。旧削除保留IDは同期起動前にoutboxへ取り込み、DB保存成功後だけSharedPreferencesから除く。既存データを初回outboxへ登録し、移行中に同期を起動しない。移行失敗はトランザクションを戻してエラーを表示し、DBを作り直してデータを失わせない。

## 共通ルール・画面

- 入力制約の正本はREQ。文字数はgrapheme単位、日本円は整数。
- 日次/履歴は暦日/暦月、予算は開始日基準の家計期間。別々の期間Providerを使用する。
- 削除は即時物理削除とoutboxの原子的保存。クラウドはtombstone、Undoは新revisionで復元。
- UI閾値は600/840の共通判定。詳細は[共通UI](features/cross-platform-shared-ui.md)。
- [screens.drawio](screens.drawio)にSCR-001〜008のワイヤーフレームとコンポーネント仕様を同じキャンバスで記載する。
- 画面は入力中/保存中/成功/失敗を区別し、失敗で入力やローカル保存済みデータを消さない。

## 旧14項目の対応

| 旧項目 | 現行機能 | 集約理由 |
| :--- | :--- | :--- |
| budget-settings-navigation-ux | [予算](features/budget-management.md) | 予算画面の操作改善 |
| apple-pay-background-sync | [外部決済](features/payment-event-ingestion.md) | 決済取り込み経路 |
| aws-cloud-sync-builtin-endpoint | [同期](features/aws-cloud-database-sync.md) | 設定・トリガーの追加 |
| expense-deletion-sync-fix | [同期](features/aws-cloud-database-sync.md) | 削除のクラウド整合性 |
| multi-device-responsive-layout | [共通UI](features/cross-platform-shared-ui.md) | 共通画面のサイズ適応 |

他の旧9識別子は同名の現行機能へ対応する。旧ファイルは移行先案内として保持し、実装方式・スキーマ・画面の正本を複製しない。旧本文と節番号は[過去資料](../archive/2026-11-01/README.md)へ保存する。現在の[実装差分](../STATUS.md)は改修対象であり、設計の矛盾として扱わない。

## 関連ADR

[ADR-0001: 全9機能の対象範囲](../adr/0001-nine-feature-scope.md)に従う。文書確定と実装・検証完了は別に判定する。
