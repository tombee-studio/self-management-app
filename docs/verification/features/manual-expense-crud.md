# 支出の手動登録・編集・削除 検証計画

- **バージョン**: v0.1.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/manual-expense-crud.md) / [SPEC](../../spec/features/manual-expense-crud.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/manual-expense-crud.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| manual-expense-crud/TC-01 | [AC-01](../../req/features/manual-expense-crud.md#ac-01) | SPEC-01〜03 | 空DB、食費カテゴリ、金額1280、固定日時2026-11-01 12:00 JST | 保存しDBを閉じ、同一ファイルで再起動 | ID1件、金額1280・カテゴリ・日時が一致 | 結合 |
| manual-expense-crud/TC-02 | [AC-02](../../req/features/manual-expense-crud.md#ac-02) | SPEC-01〜03 | 金額1280の明細と当日合計1280 | 金額1500へ更新、削除確認をキャンセル、次に承認 | 更新後1500、キャンセル後1件1500、承認後0件0円 | Widget/結合 |
| manual-expense-crud/TC-03 | [AC-03](../../req/features/manual-expense-crud.md#ac-03) | SPEC-01〜03 | 入力済フォーム、DB書き込みを失敗させる | 保存を押し、再試行で正常化 | 失敗案内・入力保持・DB0件。再試行後1件、二重保存なし | Widget |
| manual-expense-crud/TC-04 | [AC-04](../../req/features/manual-expense-crud.md#ac-04) | SPEC-01〜03 | 金額0,-1,1,99999999,100000000、式1÷0、1÷2 | 各値で評価・保存 | 1と99999999だけ保存可能。1÷0はエラー、1÷2は整数化後0で保存不可。超過を上限へ丸めない | 単体/Widget |
| manual-expense-crud/TC-05 | [AC-05](../../req/features/manual-expense-crud.md#ac-05) | SPEC-01〜03 | 未分類存在、削除済カテゴリID、1969-12-31と1970-01-01と未来日 | 新規を開いて保存し、無効値でも試す | 初期は未分類、削除済ID・1969日は拒否、1970日と未来日は有効 | 結合 |
| manual-expense-crud/TC-06 | [AC-06](../../req/features/manual-expense-crud.md#ac-06) | SPEC-01〜03 | メモ100/101grapheme、前後空白と改行、支払い方法5種 | 正規化して保存 | 100字保存・101字拒否、改行は空白、空値NULL、支払い方法を保持 | 単体/結合 |
| manual-expense-crud/TC-07 | [AC-07](../../req/features/manual-expense-crud.md#ac-07) | SPEC-01〜03 | 金額100、メモA、カテゴリ食費、日時11/2、支払い方法cash | 続けて入力を押す | 金額とメモだけ空、カテゴリ食費・日時11/2・cash保持 | Widget |
| manual-expense-crud/TC-08 | [AC-08](../../req/features/manual-expense-crud.md#ac-08) | SPEC-01〜03 | 明細1件と未送信outbox、fake clock | スワイプ→4.999秒でUndo。別ケースで5秒を経過 | 前者は同ID復元・新revision、後者は0件・削除outbox保持。明示削除にはUndoなし | Widget/結合 |
| manual-expense-crud/TC-09 | [AC-09](../../req/features/manual-expense-crud.md#ac-09) | SPEC-01〜03 | 既存明細を変更、保存前 | 閉じる/戻る/外側タップ/Escで破棄確認、入力を続ける | 全経路で確認を表示し、続行で入力保持、破棄選択だけ閉じる | Widget |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。
