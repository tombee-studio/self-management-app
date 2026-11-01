# 日次支出ダッシュボード 検証計画

- **バージョン**: v0.1.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/daily-expense-dashboard.md) / [SPEC](../../spec/features/daily-expense-dashboard.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/daily-expense-dashboard.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| daily-expense-dashboard/TC-01 | [AC-01](../../req/features/daily-expense-dashboard.md#ac-01) | SPEC-01〜03 | 11/1 食費1000・交通500、11/2 食費200 | 11/1を選択 | 日次1500、明細2件、11/2の200は含まない | 単体/Widget |
| daily-expense-dashboard/TC-02 | [AC-02](../../req/features/daily-expense-dashboard.md#ac-02) | SPEC-01〜03 | 対象日0件 | 日付選択 | 0円、空状態、追加導線、割合例外なし | Widget |
| daily-expense-dashboard/TC-03 | [AC-03](../../req/features/daily-expense-dashboard.md#ac-03) | SPEC-01〜03 | 日次1000の画面を表示 | 500追加→1000を1200へ編集→500削除 | 画面を開き直さず1500→1700→1200、内訳・明細も同値 | 結合/Widget |
| daily-expense-dashboard/TC-04 | [AC-04](../../req/features/daily-expense-dashboard.md#ac-04) | SPEC-01〜03 | JST 10/31 23:59:59.999、11/1 00:00:00、11/2 00:00:00の各100 | 11/1を集計 | 中央の100だけ計上。DST地域でも次の日界未満で判定 | 単体 |
| daily-expense-dashboard/TC-05 | [AC-05](../../req/features/daily-expense-dashboard.md#ac-05) | SPEC-01〜03 | 食費1000・交通500、次に0件 | 内訳を計算・表示 | カテゴリ和1500、比率2/3と1/3。0件では0% | 単体 |
| daily-expense-dashboard/TC-06 | [AC-06](../../req/features/daily-expense-dashboard.md#ac-06) | SPEC-01〜03 | DB購読が最初に例外、再試行後1000 | 再試行を押す | 空状態扱いせずエラー表示、再試行後1000 | Widget |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。
