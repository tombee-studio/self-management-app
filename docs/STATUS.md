# 文書の現状・DDD/契約設計レビュー

- **バージョン**: v1.0.0
- **ステータス**: done
- **確認日**: 2026-11-01（JST）

## 今回の対象

ownerの指示により、既存全9機能をDDDと契約駆動設計を組み合わせた設計へ作り直した。[REQ/ARCH-01](req/REQ.md#arch-01-ドメインモデルと契約による設計)、[ADR-0002](adr/0002-domain-contract-design.md)、[共通アーキテクチャ](spec/architecture.md)に根拠・決定・共通規則を記録した。既存60 ACと9機能の範囲・業務ルールは維持する。

前の依頼で進めていた実装変更は未コミットのまま保持し、この再設計に合わせる追加実装は今回行っていない。開始していたAndroidビルドは設計作業への切替時に停止した。作業ブランチは`feat/1-expense-management`、関連は[Issue #1](https://github.com/tombee-studio/self-management-app/issues/1)。

## 工程の現在地

| 工程 | 判定・状態 | 適用範囲 |
| :--- | :--- | :--- |
| REQ | PASS / done | 9機能60 ACを維持、ARCH-01を追加 |
| SPEC | PASS / done | 共通方針・9機能・34公開操作・OpenAPI/JSON Schema・8画面の契約対応 |
| VERIFY計画 | PASS / done | 既存61ケース＋契約34ケース＋共通ARCH6ケース＝101必須ケース |
| ADR | 0001/0002 accepted / done | 0001の全9機能対象を継承し、0002で設計方式を採用 |
| 実装・VERIFY結果 | 未完了 | 新契約のprovider/consumer・依存方向・移行・実機検証は未実施 |

上位REQを確定してからSPECを同期し、SPECレビュー後にVERIFY計画を更新した。計画doneは実施結果の合格ではない。新設計の実装開始ゲートは通過したが、実装完了ゲートは未通過。

## 既存機能への集約と変更

| 機能 | 所属・モデル | 公開契約 |
| :--- | :--- | :--- |
| 手動支出 | ExpenseLedger / Expense集約 | MAN-C01〜05 |
| 日次 | LedgerのDailyExpenseSummary ReadModel | DASH-C01〜02 |
| 履歴 | LedgerのHistory ReadModel | HIST-C01〜03 |
| 予算 | Budgeting / BudgetPlanとAllocation | BUD-C01〜03 |
| カテゴリ | CategoryCatalogとCategory | CAT-C01〜04 |
| 外部決済 | PaymentIntegration / ACLと台帳取り込み | PAY-C01〜04 |
| 同期 | Replication / OutboxChangeとSyncSession | SYN-C01〜07 |
| 共通UI | PresentationPolicy / 値・UI状態 | UI-C01〜03 |
| アイコン | BrandAssets / manifest・検査契約 | ICON-C01〜03 |

既存機能書と索引へ反映し、方式追加を理由に新しい業務機能を増やしていない。集約、不変条件、型付きPort、依存方向、事前/事後条件、副作用、失敗、冪等性を各契約で定義した。DB生成行を公開モデルにせず、DomainはFlutter・Riverpod・drift・HTTPへ依存しない。

DB目標は版3へ変更。AggregateVersions、追記型DomainEventOutbox、ReadProjectionStateを追加し、送信状態をcoalesceするSyncOutboxと分離する。版1→2→3と途中版2→3のデータ保持移行を計画した。wire版2・内部イベント版1との版混同を防ぐ。

既存TC-01以降のIDと受け入れ基準を維持し、同期TC-09だけ最終DB移行先を版3へ同期した。旧手順はGitの81798ff以前で参照できる。新しいTC-CTとTC-ARCHは既存の結果証跡を書き換えずに追加した。レガシー資料を再作成していない。

## 実装へ引き継ぐ差分

1. UIからのDB直接更新をApplication Handlerへ移し、Domain-owned Repository PortとInfrastructure adapterを分離する。
2. Expense/Catalog/BudgetPlanの不変条件を値型・集約でも保護し、expectedVersionによるCASを実装する。
3. UnitOfWorkに状態・集約版・DomainEventOutbox・SyncOutbox・読み取り世代を参加させる。カテゴリ廃止は台帳/予算/カテゴリのPortを調整する。
4. Dashboard/Historyを読取専用QueryPortへ分け、snapshotId・カーソル無効化・同一スナップショットの集計を実装する。
5. Payment ACLとLedgerIngestionPort、同期wire DTOとDomain Eventを分離し、公開スキーマと型/エラー/再送条件にconsumer/providerを合わせる。
6. DB版3の移行と101ケースを検証する。旧設計に対する単体・Widgetテストや途中コードの結果を新契約の合格として流用しない。

この一覧はコードの適合完了を保証しない。前の実装タスクに残る画面・通知・同期・実機確認も、新設計の契約へ照合して再評価する。

## 内蔵レビュー・文書検証

- 判定: PASS。上位運用・REQの範囲、9機能の責務/モデル、34契約の完全性とPortの所有、API/イベント表現、8画面の対応、VERIFYの追跡をレビューした。
- 構造検証: ローカルMarkdownリンク/アンカー516件、JSONの$ref、Schema本体、15個の正常/異常ベクトル、OpenAPI operationと契約ID、全ACと検証ケース、draw.ioのXML/セルID/契約参照を確認した。
- スキーマ例の検証は文書の機械可読定義だけを対象とし、アプリのprovider/consumer契約テストを実行済みとは扱わない。
- 未解決の設計方式・owner判断: なし。実装・実環境検証は後続作業として残す。
- コミット: 今回の文書変更だけを対象とする。未コミットのlib/test/terraform/依存/生成物を含めず、push・デプロイは行わない。
