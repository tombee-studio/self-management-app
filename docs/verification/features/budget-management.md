# 予算設定・管理 検証計画

- **バージョン**: v0.1.0
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
