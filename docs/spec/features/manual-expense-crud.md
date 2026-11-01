# 支出の手動登録・編集・削除 設計

- **バージョン**: v0.3.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/manual-expense-crud.md)。設計の正本は本書。旧仕様・詳細設計は[過去資料](../../archive/2026-11-01/features/manual-expense-crud.md)で保持する。

## SPEC-01: 入力・操作

SCR-005。今日画面・履歴から追加し、明細タップで同じフォームを編集モードで開く。新規IDはUUID。初期カテゴリは`cat_uncategorized`、初期日付は今日画面の選択日、履歴からは選択日または表示月内で選んだ日。時刻は現在時刻。支払い方法はcash、メモは空。編集時は全項目を既存値で初期化する。

| 入力 | 制約・保存値 | エラー時 |
| :--- | :--- | :--- |
| 金額 | JPY整数1〜99,999,999 | 保存不可、入力付近に理由 |
| カテゴリ | 存在する有効ID | 選択し直す案内 |
| 日時 | 1970-01-01以降。未来許可 | 保存不可 |
| 支払い方法 | cash/applePay/creditCard/eMoney/other | 外部データの未知値はother |
| メモ | 任意、trim・改行を空白化した後100文字以内 | 保存不可。空文字はNULL |

文字数はDartの`characters.length`で数える。テンキーは0〜9、00、四則演算、=、C、1字削除。乗除優先・左結合、末尾演算子は除去して評価し、小数結果は0方向へ整数化。空式・ゼロ除算・非有限値・範囲外はエラーとし、上限へ丸めて保存しない。連続演算子は最後の演算子で置換する。

保存中は保存ボタンを無効化する。成功後にフォームを閉じ、連続登録では金額・メモのみ消去する。失敗は入力を保持して再試行可能とし、自動で閉じない。編集前後に差分があれば閉じる際に破棄確認する。外側タップ・戻る・Escにも同じ確認を使う。

## SPEC-02: 永続化・削除・状態

`ExpenseFormModal`の状態を`ExpenseFormController`へ分離し、`ExpenseRepository`が保存・更新・削除・復元を提供する。`CalculatorParser`はエラー種別付き評価結果を返す。DBは共通スキーマのExpensesを使い、手動新規は`source=manual`、`externalTxId=NULL`。外部明細の編集では記録元・外部IDを保持する。

DB変更と同期outbox登録を同じトランザクションで確定する。明示削除は確認後に直ちに物理削除。スワイプ削除も直ちに物理削除し、元データを5秒間Undo状態へ保持する。取り消しは同一IDと全項目を復元して新しい更新時刻のupsertをoutboxへ登録する。画面移動・アプリ終了でUndo表示が閉じても削除とoutboxは保持される。クラウド反映は[同期](aws-cloud-database-sync.md)の責務。

Stream更新で日次・月次・予算を再計算する。保存成功と通信成功を区別し、通信失敗でローカル保存を巻き戻さない。物理削除前の5秒待機方式は採用しない。

## SPEC-03: 異常系・理由

フォームの二重送信、削除中の重複操作を抑止する。カテゴリが編集中に削除された場合は未分類への再選択を案内し、存在しないIDで保存しない。DB失敗時は成功通知・同期通知を送らない。即時削除とdurable outboxにより表示・オフライン再送を両立する。SharedPreferencesとDBに削除を別々に保存する方式は、片側だけ成功するため新設計では使わない。

## REQ対応・検証入口

- [manual-expense-crud/AC-01](../../req/features/manual-expense-crud.md#ac-01): 本書のSPEC-01〜03で具体化。
- [manual-expense-crud/AC-02](../../req/features/manual-expense-crud.md#ac-02): 本書のSPEC-01〜03で具体化。
- [manual-expense-crud/AC-03](../../req/features/manual-expense-crud.md#ac-03): 本書のSPEC-01〜03で具体化。
- [manual-expense-crud/AC-04](../../req/features/manual-expense-crud.md#ac-04): 本書のSPEC-01〜03で具体化。
- [manual-expense-crud/AC-05](../../req/features/manual-expense-crud.md#ac-05): 本書のSPEC-01〜03で具体化。
- [manual-expense-crud/AC-06](../../req/features/manual-expense-crud.md#ac-06): 本書のSPEC-01〜03で具体化。
- [manual-expense-crud/AC-07](../../req/features/manual-expense-crud.md#ac-07): 本書のSPEC-01〜03で具体化。
- [manual-expense-crud/AC-08](../../req/features/manual-expense-crud.md#ac-08): 本書のSPEC-01〜03で具体化。
- [manual-expense-crud/AC-09](../../req/features/manual-expense-crud.md#ac-09): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。
