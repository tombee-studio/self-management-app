# カテゴリマスター管理 検証計画

- **バージョン**: v1.0.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/category-master-management.md) / [SPEC](../../spec/features/category-master-management.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/category-master-management.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| category-master-management/TC-01 | [AC-01](../../req/features/category-master-management.md#ac-01) | SPEC-01〜03 | カテゴリ新規、名称食材、許可アイコン、#EF4444 | 保存し再起動 | 名称・アイコン・色が一致 | 結合 |
| category-master-management/TC-02 | [AC-02](../../req/features/category-master-management.md#ac-02) | SPEC-01〜03 | A/B/Cの順序 | C/A/Bへ並べ替え | 管理一覧と支出フォームがC/A/B、DB sortOrderも一致 | Widget/結合 |
| category-master-management/TC-03 | [AC-03](../../req/features/category-master-management.md#ac-03) | SPEC-01〜03 | Aを参照する明細2件合計1500、未分類1件 | A削除、未分類の編集・削除も呼び出す | 2件とも未分類へ移り合計不変、未分類の変更はUI/Repository双方で拒否 | 結合 |
| category-master-management/TC-04 | [AC-04](../../req/features/category-master-management.md#ac-04) | SPEC-01〜03 | 名称空白、20/21grapheme、ＡとA | 保存 | 空白・21字・正規化重複を拒否、20字を保存 | 単体/結合 |
| category-master-management/TC-05 | [AC-05](../../req/features/category-master-management.md#ac-05) | SPEC-01〜03 | カテゴリに支出と配分、DBの途中処理で失敗注入 | 安全削除 | 本体/支出/配分/outboxすべてロールバック。成功時だけ全反映 | 結合 |
| category-master-management/TC-06 | [AC-06](../../req/features/category-master-management.md#ac-06) | SPEC-01〜03 | 空DBと既存DB | 初回起動、再起動、版1から移行 | 固定IDの標準9件が1件ずつ存在、既存カテゴリ・明細を失わない | 結合 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。

## ドメイン・公開契約の検証（ARCH-01）

[共通アーキテクチャ](../../spec/architecture.md)と機能書の契約を対象とする。既存TC-01以降を残し、以下のTC-CTを追加する。文書での契約定義・スキーマ例の検証をprovider/consumer実装の合格と混同しない。

基準fixture: 未分類・カテゴリA/B、A参照支出2件1500円・配分。正規化重複名、欠落/重複並びID、stale Catalog版と削除途中のDB失敗を用意。

| ケースID | 対応契約・要求 | 入力/前提・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| category-master-management/TC-CT-01 | [CAT-C01](../../spec/features/category-master-management.md#cat-c01)、REQ/ARCH-01、AC-01/04 | 上のfixtureからUpsertCategoryの正常入力と、事前条件「名前・許可アイコン・色が有効、同名なし、対象はシステム予約IDでない、版一致」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「追加/変更・Catalog版・CatalogChanged/Outboxを一体保存。追加順は末尾」を実値/件数で確認。失敗はValidationFailed/InvariantViolation/VersionConflict/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「同ID同値はAlreadyApplied。IDの異なる同名は失敗」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| category-master-management/TC-CT-02 | [CAT-C02](../../spec/features/category-master-management.md#cat-c02)、REQ/ARCH-01、AC-02 | 上のfixtureからReorderCatalogの正常入力と、事前条件「現行の全IDが重複なく1回ずつ含まれ、版一致」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「連続sortOrderと新Catalog版を一体保存。支出入力へ同じ順序を射影」を実値/件数で確認。失敗はValidationFailed/VersionConflict/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「同じ並びならAlreadyApplied」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| category-master-management/TC-CT-03 | [CAT-C03](../../spec/features/category-master-management.md#cat-c03)、REQ/ARCH-01、AC-03/05 | 上のfixtureからRetireCategoryの正常入力と、事前条件「対象が存在し未分類でない。版一致」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「同UoWで全対象Expenseのカテゴリ参照を未分類へ変更し各版/Outbox更新、Budget配分削除と版更新、Catalogから除去。支出金額/ID/日時を保持」を実値/件数で確認。失敗はInvariantViolation/NotFound/VersionConflict/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「廃止済みはAlreadyRetired、二重移行や追加削除イベントなし」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| category-master-management/TC-CT-04 | [CAT-C04](../../spec/features/category-master-management.md#cat-c04)、REQ/ARCH-01、AC-06 | 上のfixtureからEnsureDefaultCatalogの正常入力と、事前条件「空Catalogまたは既存Catalogを識別できる」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「初回のみ標準9件作成。既存のユーザー変更・IDは上書きしない」を実値/件数で確認。失敗はStorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「再起動・移行で重複生成しない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |

Portのfakeと本番adapterへ同じcontract suiteを適用する。Queryは業務DB・版・Outboxの変更回数0、Commandはcommit後に限るイベント発行を監視する。同期は部分commit契約に従いACK済みだけが残り、cursor/lastSuccessは成功条件を満たした時だけ更新されることを確認する。UI・アイコンではDB参加を要求せず、純粋Policy/ビルド契約と実機証跡を確認する。

追加契約テストは今回未実施。途中実装の既存テスト結果を新契約への合格証跡として流用しない。
