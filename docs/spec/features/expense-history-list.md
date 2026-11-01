# 支出履歴・過去一覧 設計

- **バージョン**: v1.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/expense-history-list.md)。設計の正本は本書。

## ドメイン境界・モデル

分類: **ExpenseLedgerの読み取りモデル（検索・ページング）**。[共通アーキテクチャ](../architecture.md)と[ADR-0002](../../adr/0002-domain-contract-design.md)に従う。全契約はv1.0.0。既存REQの業務範囲・AC番号を維持する。

| モデル | 所有・構成・制約 |
| :--- | :--- |
| HistoryFilter（値） | CalendarMonth|All、SearchText、CategoryId集合、source、表示モード |
| HistoryPage / HistoryTotals（ReadModel） | ExpenseRow[]、opaqueCursor?、snapshotId、件数/結果合計/月間合計/日別合計。集約を所有しない |

### 不変条件・依存方向

- ページ取得と全件合計に同じ正規化predicateを使い、読み込み件数を全件合計として扱わない。
- カーソルはフィルタ指紋・スナップショット世代・最後の(spentAt,id)を含み、別条件で再利用しない。

HistoryQueryPort.query/totals/watchInvalidation、TimeZone。DriftHistoryQueryAdapterはjoin/aggregateを直接最適化できるが、DomainへのDB依存を導入しない。

### 公開契約

契約の成功・失敗・版・トランザクション・再試行の共通意味は[共通規則](../architecture.md#5-契約の共通規則)。Operationの引数型は上の値型/DTOとSPEC-01の項目定義を使い、DB行型を公開しない。QueryのsnapshotIdとVersionは互換ではない。

<a id="hist-c01"></a>
#### HIST-C01: QueryHistory

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `QueryHistory{filter,cursor?,pageSize:50} → Result<HistoryPage>` |
| 事前条件 | filter有効、cursorの条件指紋とsnapshotIdが一致 |
| 成功後の保証・変更範囲 | spentAt/ID降順、50件以下、nextCursorを返す。SQLワイルドカードを文字として検索。DB変更なし |
| 失敗 | ValidationFailed/CursorInvalidated/StorageFailure |
| 冪等性・再試行 | 同snapshot/cursorは同じID順。無効カーソルは先頭から再取得 |
| 対応REQ | [AC-02](../../req/features/expense-history-list.md#ac-02), [AC-03](../../req/features/expense-history-list.md#ac-03), [AC-05](../../req/features/expense-history-list.md#ac-05), [AC-06](../../req/features/expense-history-list.md#ac-06), [AC-07](../../req/features/expense-history-list.md#ac-07) |

<a id="hist-c02"></a>
#### HIST-C02: GetHistoryTotals

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `GetHistoryTotals{filter,snapshotId} → Result<HistoryTotals>` |
| 事前条件 | QueryHistoryと同じsnapshotを指定 |
| 成功後の保証・変更範囲 | 対象全件の件数・結果合計・日別小計、月指定時は検索前の月間総額を別値で返す |
| 失敗 | CursorInvalidated/StorageFailure |
| 冪等性・再試行 | 同snapshotではページ追加によらず同じ合計 |
| 対応REQ | [AC-01](../../req/features/expense-history-list.md#ac-01), [AC-02](../../req/features/expense-history-list.md#ac-02), [AC-03](../../req/features/expense-history-list.md#ac-03) |

<a id="hist-c03"></a>
#### HIST-C03: SelectHistoryDate

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `SelectHistoryDate{month,date?,viewMode} → Result<HistorySelection>` |
| 事前条件 | dateはmonth内。Allでは一覧だけ許可 |
| 成功後の保証・変更範囲 | 月変更で日付選択とcursorを解除。日選択時はその日の全該当明細を返す |
| 失敗 | ValidationFailed/StorageFailure |
| 冪等性・再試行 | 選択状態だけ変更し、台帳を書き換えない |
| 対応REQ | [AC-04](../../req/features/expense-history-list.md#ac-04) |

## SPEC-01: 閲覧・検索

SCR-004。初期は当月、一覧表示。月移動で対象を変更し、カレンダー選択日とページカーソルを解除する。全期間は一覧だけで選択できる。月間合計は表示月全件の合計として常に示し、検索条件がある場合は対象件数・検索結果合計も別表示する。カレンダー表示の全期間切替では一覧へ戻る。

期間・キーワード・カテゴリ・記録元はAND、カテゴリ内はOR。キーワードとメモをNFKC正規化・英字lowercase・trimして部分一致比較し、SQLのワイルドカード文字はエスケープする。ローカルの店舗名はmemoに含むため独立merchantName列は作らない。sourceはmanual/apple_payで絞り、paymentMethodとは混同しない。

タイムラインはローカル暦日でグループ化、日内はspentAt降順・ID降順。日別小計は検索後の該当日全件を集計し、読み込み済み50件だけを合計しない。カレンダーでは選択月の検索後の日別合計と、選択日の全対象明細を表示する。検索0件は案内と条件クリア、支出のない日は追加導線を表示する。

## SPEC-02: 状態・クエリ

ExpenseHistoryScreen → HistoryQueryService → HistoryQueryPort。フィルタとカーソルはApplication DTO、SQL結合/集計はDriftHistoryQueryAdapterだけに置く。

以下はPortのInfrastructure実装と計算/表示Policyの具体化。具象DB・通知SDKをDomainへ持ち込まない。複数の物理テーブルに分かれていても、上の集約境界と契約単位で保存する。


月・日範囲は共通のUTC変換を使い、条件一致件数・総額・日別総額はページ取得と別クエリで計算する。検索正規化用の`memoSearch`列を持ち、保存時・移行時に更新する。インデックスはExpenses(spentAt,id)、categoryId、source。検索の最適化を理由に結果条件を変えない。

## SPEC-03: 異常系・理由

検索は入力後200msで再実行し、以前のリクエスト結果を新しい条件に上書きしない。空キーワード・カテゴリ未選択は絞り込まない。エラー時は条件を保持して再試行、追加ページ失敗は既表示明細を残す。月間カレンダーは月内データだけを扱い、前後月の件数を合計しない。キーセットでページ境界の挿入による重複を抑える。

## REQ対応・検証入口

- [expense-history-list/AC-01](../../req/features/expense-history-list.md#ac-01): 本書のSPEC-01〜03で具体化。
- [expense-history-list/AC-02](../../req/features/expense-history-list.md#ac-02): 本書のSPEC-01〜03で具体化。
- [expense-history-list/AC-03](../../req/features/expense-history-list.md#ac-03): 本書のSPEC-01〜03で具体化。
- [expense-history-list/AC-04](../../req/features/expense-history-list.md#ac-04): 本書のSPEC-01〜03で具体化。
- [expense-history-list/AC-05](../../req/features/expense-history-list.md#ac-05): 本書のSPEC-01〜03で具体化。
- [expense-history-list/AC-06](../../req/features/expense-history-list.md#ac-06): 本書のSPEC-01〜03で具体化。
- [expense-history-list/AC-07](../../req/features/expense-history-list.md#ac-07): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。

## 契約検証・実装への移行

[機能別検証計画](../../verification/features/expense-history-list.md)のTC-CTで公開契約ごとの前提違反・成功保証・不変条件・失敗時副作用・再試行を検証する。既存SPEC-01〜03の業務/画面条件を契約の詳細規則として維持する。既存実装と途中の変更は移行元であり、本設計に適合済みとは扱わない。
