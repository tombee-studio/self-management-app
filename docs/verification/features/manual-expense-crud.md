# 支出の手動登録・編集・削除 検証計画

- **バージョン**: v1.0.0
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

## ドメイン・公開契約の検証（ARCH-01）

[共通アーキテクチャ](../../spec/architecture.md)と機能書の契約を対象とする。既存TC-01以降を残し、以下のTC-CTを追加する。文書での契約定義・スキーマ例の検証をprovider/consumer実装の合格と混同しない。

基準fixture: Expense exp-1、食費、金額1280、11/1、version=1。金額0/100000000、欠落カテゴリ、同ID別内容、stale版、削除後4.999秒/5秒を用意。

| ケースID | 対応契約・要求 | 入力/前提・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| manual-expense-crud/TC-CT-01 | [MAN-C01](../../spec/features/manual-expense-crud.md#man-c01)、REQ/ARCH-01、AC-01/03/04/05/06/07 | 上のfixtureからRecordExpenseの正常入力と、事前条件「値型が有効、ID未使用、有効カテゴリの存在/カタログ版一致」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「version=1のExpenseを作成しExpenseRecordedとOutboxを1件だけ確定。別明細は変更しない」を実値/件数で確認。失敗はValidationFailed/NotFound/VersionConflict/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「同じID・同じ正規化済み内容はAlreadyApplied。別内容の同一IDはVersionConflict」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| manual-expense-crud/TC-CT-02 | [MAN-C02](../../spec/features/manual-expense-crud.md#man-c02)、REQ/ARCH-01、AC-02/03/04/05/06 | 上のfixtureからModifyExpenseの正常入力と、事前条件「存在、版一致、変更後の全不変条件成立」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「ID・作成日時・記録元は維持、版を1進めExpenseChangedを確定」を実値/件数で確認。失敗はValidationFailed/NotFound/VersionConflict/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「適用済み同値はAlreadyApplied、他の版/値はConflict」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| manual-expense-crud/TC-CT-03 | [MAN-C03](../../spec/features/manual-expense-crud.md#man-c03)、REQ/ARCH-01、AC-02/03/08 | 上のfixtureからDeleteExpenseの正常入力と、事前条件「存在・版一致、明示削除はUIで確認済み」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「Expense行を即時削除、削除版・ExpenseDeleted・tombstone Outboxを確定。swipeだけUndoGrantを発行」を実値/件数で確認。失敗はNotFound/VersionConflict/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「削除済みはAlreadyDeleted、Grant再発行なし」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| manual-expense-crud/TC-CT-04 | [MAN-C04](../../spec/features/manual-expense-crud.md#man-c04)、REQ/ARCH-01、AC-08 | 上のfixtureからRestoreExpenseの正常入力と、事前条件「5秒未満の有効Grant、版がGrantの削除版、同IDの明細未復元」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「同ID・元内容を復元、版を進めExpenseRestored/新Outboxを確定。Grant使用済み化」を実値/件数で確認。失敗はUndoExpired/VersionConflict/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「同Grantの適用済みは同じ復元結果。期限切れで新規登録しない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| manual-expense-crud/TC-CT-05 | [MAN-C05](../../spec/features/manual-expense-crud.md#man-c05)、REQ/ARCH-01、AC-09 | 上のfixtureからCloseExpenseDraftの正常入力と、事前条件「未保存差分があれば確認を経る」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「discardだけUIドラフトを破棄。DB/版/Outboxを変更しない。continueは全入力保持」を実値/件数で確認。失敗はなし（UI操作のみ）と一致し、未commitなら状態/版/Outbox不変。再試行は「同じ判断は同じ状態。保存中の閉じるは無効」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |

Portのfakeと本番adapterへ同じcontract suiteを適用する。Queryは業務DB・版・Outboxの変更回数0、Commandはcommit後に限るイベント発行を監視する。同期は部分commit契約に従いACK済みだけが残り、cursor/lastSuccessは成功条件を満たした時だけ更新されることを確認する。UI・アイコンではDB参加を要求せず、純粋Policy/ビルド契約と実機証跡を確認する。

追加契約テストは今回未実施。途中実装の既存テスト結果を新契約への合格証跡として流用しない。
