# 支出の手動登録・編集・削除 設計

- **バージョン**: v1.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/manual-expense-crud.md)。設計の正本は本書。

## ドメイン境界・モデル

分類: **ExpenseLedgerの更新モデル**。[共通アーキテクチャ](../architecture.md)と[ADR-0002](../../adr/0002-domain-contract-design.md)に従う。全契約はv1.0.0。既存REQの業務範囲・AC番号を維持する。

| モデル | 所有・構成・制約 |
| :--- | :--- |
| Expense（集約ルート） | ExpenseId、MoneyJPY、CategoryId、SpentAt、PaymentMethod、Memo、source、externalTxId、AggregateVersion。型生成時と遷移時に不変条件を検証 |
| UndoGrant（値/プロセス内許可） | 5秒未満、同じ削除版、未使用。再起動・期限切れで失効 |

### 不変条件・依存方向

- Expenseは有効な支出金額・日時・存在するカテゴリだけを保持する。カテゴリ参照はIDとカタログ版で検証し、他集約のEntityを内包しない。
- source/externalTxIdは生成元の属性で、手動の編集操作では変更しない。
- 明細変更・集約版・Outboxは同一UnitOfWork。失敗でいずれかだけ確定させない。

ExpenseRepository.load/save/delete（expectedVersion必須）、CategoryLookup、LedgerCommitPort、UnitOfWork、Clock。UIはExpenseCommandHandlerだけを呼ぶ。DB生成ExpenseクラスをApplicationの戻り値に使わない。

### 公開契約

契約の成功・失敗・版・トランザクション・再試行の共通意味は[共通規則](../architecture.md#5-契約の共通規則)。Operationの引数型は上の値型/DTOとSPEC-01の項目定義を使い、DB行型を公開しない。QueryのsnapshotIdとVersionは互換ではない。

<a id="man-c01"></a>
#### MAN-C01: RecordExpense

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `RecordExpense{id,amount,categoryId,spentAt,paymentMethod,memo} → Result<ExpenseView{id,version}>` |
| 事前条件 | 値型が有効、ID未使用、有効カテゴリの存在/カタログ版一致 |
| 成功後の保証・変更範囲 | source=manual・externalTxId=Noneでversion=1のExpenseを作成しExpenseRecordedとOutboxを1件だけ確定。別明細は変更しない |
| 失敗 | ValidationFailed/NotFound/VersionConflict/StorageFailure |
| 冪等性・再試行 | 同じID・同じ正規化済み内容はAlreadyApplied。別内容の同一IDはVersionConflict |
| 対応REQ | [AC-01](../../req/features/manual-expense-crud.md#ac-01), [AC-03](../../req/features/manual-expense-crud.md#ac-03), [AC-04](../../req/features/manual-expense-crud.md#ac-04), [AC-05](../../req/features/manual-expense-crud.md#ac-05), [AC-06](../../req/features/manual-expense-crud.md#ac-06), [AC-07](../../req/features/manual-expense-crud.md#ac-07) |

<a id="man-c02"></a>
#### MAN-C02: ModifyExpense

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ModifyExpense{id,expectedVersion,changes} → Result<ExpenseView>` |
| 事前条件 | 存在、版一致、変更後の全不変条件成立 |
| 成功後の保証・変更範囲 | ID・作成日時・記録元は維持、版を1進めExpenseChangedを確定 |
| 失敗 | ValidationFailed/NotFound/VersionConflict/StorageFailure |
| 冪等性・再試行 | 適用済み同値はAlreadyApplied、他の版/値はConflict |
| 対応REQ | [AC-02](../../req/features/manual-expense-crud.md#ac-02), [AC-03](../../req/features/manual-expense-crud.md#ac-03), [AC-04](../../req/features/manual-expense-crud.md#ac-04), [AC-05](../../req/features/manual-expense-crud.md#ac-05), [AC-06](../../req/features/manual-expense-crud.md#ac-06) |

<a id="man-c03"></a>
#### MAN-C03: DeleteExpense

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `DeleteExpense{id,expectedVersion,kind:explicit|swipe} → Result<DeletionView{id,version,undoGrant?}>` |
| 事前条件 | 存在・版一致、明示削除はUIで確認済み |
| 成功後の保証・変更範囲 | Expense行を即時削除、削除版・ExpenseDeleted・tombstone Outboxを確定。swipeだけUndoGrantを発行 |
| 失敗 | NotFound/VersionConflict/StorageFailure |
| 冪等性・再試行 | 削除済みはAlreadyDeleted、Grant再発行なし |
| 対応REQ | [AC-02](../../req/features/manual-expense-crud.md#ac-02), [AC-03](../../req/features/manual-expense-crud.md#ac-03), [AC-08](../../req/features/manual-expense-crud.md#ac-08) |

<a id="man-c04"></a>
#### MAN-C04: RestoreExpense

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `RestoreExpense{grant} → Result<ExpenseView>` |
| 事前条件 | 5秒未満の有効Grant、版がGrantの削除版、同IDの明細未復元 |
| 成功後の保証・変更範囲 | 同ID・元内容を復元、版を進めExpenseRestored/新Outboxを確定。Grant使用済み化 |
| 失敗 | UndoExpired/VersionConflict/StorageFailure |
| 冪等性・再試行 | 同Grantの適用済みは同じ復元結果。期限切れで新規登録しない |
| 対応REQ | [AC-08](../../req/features/manual-expense-crud.md#ac-08) |

<a id="man-c05"></a>
#### MAN-C05: CloseExpenseDraft

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `CloseExpenseDraft{draft,decision:discard|continue} → DraftDecision` |
| 事前条件 | 未保存差分があれば確認を経る |
| 成功後の保証・変更範囲 | discardだけUIドラフトを破棄。DB/版/Outboxを変更しない。continueは全入力保持 |
| 失敗 | なし（UI操作のみ） |
| 冪等性・再試行 | 同じ判断は同じ状態。保存中の閉じるは無効 |
| 対応REQ | [AC-09](../../req/features/manual-expense-crud.md#ac-09) |

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

ExpenseFormModal → ExpenseFormController → ExpenseCommandHandler → ExpenseRepository/CategoryLookup/UoW → Drift adapters。フォームはDraftを保持し、Domain Expenseとは別モデルにする。

以下はPortのInfrastructure実装と計算/表示Policyの具体化。具象DB・通知SDKをDomainへ持ち込まない。複数の物理テーブルに分かれていても、上の集約境界と契約単位で保存する。


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

## 契約検証・実装への移行

[機能別検証計画](../../verification/features/manual-expense-crud.md)のTC-CTで公開契約ごとの前提違反・成功保証・不変条件・失敗時副作用・再試行を検証する。既存SPEC-01〜03の業務/画面条件を契約の詳細規則として維持する。既存実装と途中の変更は移行元であり、本設計に適合済みとは扱わない。
