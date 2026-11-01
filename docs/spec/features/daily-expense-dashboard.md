# 日次支出ダッシュボード 設計

- **バージョン**: v0.4.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/daily-expense-dashboard.md)。設計の正本は本書。

## SPEC-01: 表示・集計

SCR-001。起動時は今日、前日・翌日・日付ピッカー・今日へ戻るで選択日を変更する。日付は1970-01-01以降、未来日も許可。日次合計、カテゴリ内訳、予算の日次目安、明細、追加ボタンを表示する。

集計対象は端末ローカルの日界`[選択日00:00, 翌日00:00)`をUTCへ変換した範囲。合計はamountの整数和。カテゴリは金額降順、同額ならsortOrder・ID順。割合は合計が正の場合のみ`カテゴリ額/日次合計`、0件では0%とする。表示の丸めで割合の合計が100%からずれても金額合計を丸めない。予算値は[予算](budget-management.md)の家計期間サマリーを参照し、日次実績と予算期間実績を別ラベルにする。

明細はspentAt降順・ID降順、カテゴリ・金額・メモ・時刻・支払い方法を表示する。0件は0円と追加導線。読み込み中はインジケーター、失敗は再試行。明細タップは編集、スワイプは[手動支出](manual-expense-crud.md)の即時削除・5秒Undoへ委譲する。

## SPEC-02: 構成・データフロー

`DailyExpenseDashboardScreen` → `selectedDateProvider` → `ExpenseRepository.watchDay` → `dailyExpensesStreamProvider`。DBのExpensesとCategoriesを結合し、共通関数`aggregateExpenses`で合計・カテゴリ内訳を計算する。表示日変更で旧Stream購読を解放する。日界の終端は23:59:59.999ではなく翌日未満とし、保存精度と夏時間による欠落を避ける。

幅840以上は左ペインに日付・サマリー・内訳、右に明細と選択中のインライン編集。600以上840未満はサマリー・内訳を横並び、600未満は縦に並べ、いずれもスクロールで同じ内容を提供する。親の選択日と編集対象をProviderで保持し、リサイズで状態を初期化しない。

## SPEC-03: エラー・理由

DBの失敗を空データとして扱わない。再試行は同じ選択日の購読を再作成する。金額表示は`¥#,##0`、大きな数値は折り返し・縮小で欠けを防ぐ。Pull-to-refreshは同期実行後にStreamの更新を待ち、通信失敗でも直前のローカル表示を保持する。集計を保存列として持たず、明細から計算することで更新時の二重管理を避ける。

## REQ対応・検証入口

- [daily-expense-dashboard/AC-01](../../req/features/daily-expense-dashboard.md#ac-01): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-02](../../req/features/daily-expense-dashboard.md#ac-02): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-03](../../req/features/daily-expense-dashboard.md#ac-03): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-04](../../req/features/daily-expense-dashboard.md#ac-04): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-05](../../req/features/daily-expense-dashboard.md#ac-05): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-06](../../req/features/daily-expense-dashboard.md#ac-06): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。
