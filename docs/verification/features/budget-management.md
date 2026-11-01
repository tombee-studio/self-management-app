# 予算設定・管理 検証計画

- **バージョン**: v1.0.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/budget-management.md) / [SPEC](../../spec/features/budget-management.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/budget-management.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| budget-management/TC-01 | [AC-01](../../req/features/budget-management.md#ac-01) | SPEC-01〜03 | 月間150000、開始25、配分30000、通知ON | 保存、DB再起動 | 全設定と配分を復元 | 結合 |
| budget-management/TC-02 | [AC-02](../../req/features/budget-management.md#ac-02) | SPEC-01〜03 | 開始25、今日11/1、10/25に1000、11/24に2000、11/25に4000 | 予算期間集計 | 期間10/25〜11/24、実績3000。11/25の4000は含まない | 単体/結合 |
| budget-management/TC-03 | [AC-03](../../req/features/budget-management.md#ac-03) | SPEC-01〜03 | 予算画面をPush/タブで開く、DB正常/失敗の各条件 | 背景/Doneを操作、保存 | 解除でき、正常はpop/今日へ移動、失敗は入力保持・遷移なし | Widget |
| budget-management/TC-04 | [AC-04](../../req/features/budget-management.md#ac-04) | SPEC-01〜03 | 総額0/1/99999999/100000000、開始0/1/28/29、配分が総額超過 | 保存 | 金額・開始の境界を制約通り判定。配分超過は警告して保存 | 単体/Widget |
| budget-management/TC-05 | [AC-05](../../req/features/budget-management.md#ac-05) | SPEC-01〜03 | 期間11/1〜11/30、今日11/10、予算30000、実績9000 | 目安を計算 | 残額21000、残日数21、目安1000。実績31000なら目安0・残額-1000 | 単体 |
| budget-management/TC-06 | [AC-06](../../req/features/budget-management.md#ac-06) | SPEC-01〜03 | 11月予算30000、実績6000、今日11/3と11/4 | 予測を計算 | 11/3予測60000で警告なし、11/4予測45000で警告あり。DSTでも暦日数は同じ | 単体 |
| budget-management/TC-07 | [AC-07](../../req/features/budget-management.md#ac-07) | SPEC-01〜03 | 予算10000、通知許可/拒否、fake notifierと通知履歴 | 実績8000→10000→再起動→10000 | 許可時80/100各1回、再起動で増えない。拒否でも明細・集計正常 | 結合/手動 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。

## ドメイン・公開契約の検証（ARCH-01）

[共通アーキテクチャ](../../spec/architecture.md)と機能書の契約を対象とする。既存TC-01以降を残し、以下のTC-CTを追加する。文書での契約定義・スキーマ例の検証をprovider/consumer実装の合格と混同しない。

基準fixture: 月30000・開始25・配分、11/10実績9000、経過3/4日、80/100%の閾値とreceipt、stale Plan版を用意。

| ケースID | 対応契約・要求 | 入力/前提・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| budget-management/TC-CT-01 | [BUD-C01](../../spec/features/budget-management.md#bud-c01)、REQ/ARCH-01、AC-01/03/04 | 上のfixtureからConfigureBudgetPlanの正常入力と、事前条件「版一致、金額・開始日・存在するカテゴリ参照が有効」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「Plan/配分/版/Outboxを一体保存。配分超過はWarning。成功後のみUI遷移」を実値/件数で確認。失敗はValidationFailed/VersionConflict/NotFound/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「同値の適用済みはAlreadyApplied。失敗で画面入力を破棄しない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| budget-management/TC-CT-02 | [BUD-C02](../../spec/features/budget-management.md#bud-c02)、REQ/ARCH-01、AC-02/05/06 | 上のfixtureからCalculateBudgetSummaryの正常入力と、事前条件「periodExpensesの期間がplan.resolvePeriodと一致、スナップショット世代一致」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「暦日単位の残額・日次目安・予測を返す。最初3日間は予測警告なし。純粋関数」を実値/件数で確認。失敗はValidationFailed/SnapshotMismatchと一致し、未commitなら状態/版/Outbox不変。再試行は「同じ入力は同じ計算値。DB・通知に副作用なし」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| budget-management/TC-CT-03 | [BUD-C03](../../spec/features/budget-management.md#bud-c03)、REQ/ARCH-01、AC-07 | 上のfixtureからEvaluateBudgetThresholdsの正常入力と、事前条件「Plan版・期間・summaryの対応が一致」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「periodStart/thresholdのreceiptを一度だけ確定。commit後に80/100通知を順に試み、拒否でも台帳/Planは変更しない」を実値/件数で確認。失敗はSnapshotMismatch/StorageFailure。通知拒否はWarningと一致し、未commitなら状態/版/Outbox不変。再試行は「同期間・閾値の再評価は通知を増やさない。OFF中もreceiptを残す」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |

Portのfakeと本番adapterへ同じcontract suiteを適用する。Queryは業務DB・版・Outboxの変更回数0、Commandはcommit後に限るイベント発行を監視する。同期は部分commit契約に従いACK済みだけが残り、cursor/lastSuccessは成功条件を満たした時だけ更新されることを確認する。UI・アイコンではDB参加を要求せず、純粋Policy/ビルド契約と実機証跡を確認する。

追加契約テストは今回未実施。途中実装の既存テスト結果を新契約への合格証跡として流用しない。
