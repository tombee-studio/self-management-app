# 支出履歴・過去一覧 設計

- **バージョン**: v0.3.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/expense-history-list.md)。設計の正本は本書。旧仕様・詳細設計は[過去資料](../../archive/2026-11-01/features/expense-history-list.md)で保持する。

## SPEC-01: 閲覧・検索

SCR-004。初期は当月、一覧表示。月移動で対象を変更し、カレンダー選択日とページカーソルを解除する。全期間は一覧だけで選択できる。月間合計は表示月全件の合計として常に示し、検索条件がある場合は対象件数・検索結果合計も別表示する。カレンダー表示の全期間切替では一覧へ戻る。

期間・キーワード・カテゴリ・記録元はAND、カテゴリ内はOR。キーワードとメモをNFKC正規化・英字lowercase・trimして部分一致比較し、SQLのワイルドカード文字はエスケープする。ローカルの店舗名はmemoに含むため独立merchantName列は作らない。sourceはmanual/apple_payで絞り、paymentMethodとは混同しない。

タイムラインはローカル暦日でグループ化、日内はspentAt降順・ID降順。日別小計は検索後の該当日全件を集計し、読み込み済み50件だけを合計しない。カレンダーでは選択月の検索後の日別合計と、選択日の全対象明細を表示する。検索0件は案内と条件クリア、支出のない日は追加導線を表示する。

## SPEC-02: 状態・クエリ

`ExpenseHistoryScreen`、`historyFilterProvider`（month/all、keyword、categoryIds、source、selectedDay、viewMode）、`ExpenseRepository.queryHistory`を分離する。全期間は`(spentAt,id)`によるキーセット方式で50件ずつ取得し、カーソルより古い明細を取得する。カテゴリ選択・検索条件変更時はカーソルをリセットする。DB変更通知時は取得済み範囲を再検索し、IDで重複排除する。絞り込みと合計に同じpredicateを適用する。

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
