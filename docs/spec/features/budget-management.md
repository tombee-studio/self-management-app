# 予算設定・管理 設計

- **バージョン**: v0.3.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/budget-management.md)。設計の正本は本書。旧仕様・詳細設計は[過去資料](../../archive/2026-11-01/features/budget-management.md)で保持する。

## SPEC-01: 入力・期間・計算

SCR-006。月間総予算1〜99,999,999円、開始日1〜28、カテゴリ配分0〜99,999,999円、カテゴリ配分有効・通知有効を編集する。配分合計が総予算超過なら超過額を警告するが保存可能。無効な総予算・開始日は保存不可。背景タップ・Done・タブ移動でキーボード解除、保存成功後にPushで開いた場合pop、タブで開いた場合今日タブへ戻る。失敗時は入力保持・再試行。

期間は今日が開始日以降なら当月開始日、前なら前月開始日をstartとし、endExclusiveを翌月開始日とする。実績は`[start,endExclusive)`の全支出。履歴の暦月合計を入力に使わない。日数はローカルの年・月・日をUTCの暦日値に写して差を計算し、夏時間や現在の時刻で残日数を減らさない。

- 期間総日数 = endExclusiveの暦日差。
- 経過日数 = 今日とstartの暦日差 + 1。
- 残日数 = endExclusiveと今日の暦日差（今日を含む）。
- 残予算 = 月間予算 − 期間実績（負を許容）。
- 日次目安 = max(0, floor(残予算 / 残日数))。
- 予測総額 = floor(期間実績 / 経過日数 × 期間総日数)。
- 最初の3日間（経過日数1〜3）は予測警告なし。4日目以降に予測総額>予算なら警告。

期間内に事前入力した未来支出も期間実績へ含める。ラベルは「予算期間の実績」とし、未来入力を無視した実消費とは表示しない。

## SPEC-02: 構成・通知

`BudgetSettingsScreen`/`BudgetController`、`BudgetRepository`、`BudgetCalculationService.resolveBudgetPeriod/calculate`、`budgetPeriodExpensesProvider`、`BudgetNotificationService`。BudgetsはID=1の1レコード、CategoryBudgetsはカテゴリごとの配分。設定・配分・同期outboxを単一DBトランザクションで保存する。

通知はflutter_local_notificationsのアダプタで発行し、権限拒否を保存失敗としない。期間開始日+閾値（80/100）をキーとする通知履歴をDBに保存する。80%以上・100%以上へ初めて到達した時に各1回通知する。同じ変更で両閾値へ到達した場合は80%・100%を順に各1回発行する。再計算・アプリ再起動で重複通知しない。通知OFF中に閾値到達した場合も履歴を記録し、ONへの変更で過去通知を大量発行しない。

## SPEC-03: エラー・理由

カテゴリ削除時は配分も削除する。DB失敗時に画面遷移・成功通知しない。予算期間の集計Streamを使用し、開始日変更で再購読する。保存後は変更した予算と同じ期間をダッシュボードで表示する。純粋な日付・計算サービスと端末通知を分離して、暦日境界・権限拒否を個別に検証できる構成にする。

## REQ対応・検証入口

- [budget-management/AC-01](../../req/features/budget-management.md#ac-01): 本書のSPEC-01〜03で具体化。
- [budget-management/AC-02](../../req/features/budget-management.md#ac-02): 本書のSPEC-01〜03で具体化。
- [budget-management/AC-03](../../req/features/budget-management.md#ac-03): 本書のSPEC-01〜03で具体化。
- [budget-management/AC-04](../../req/features/budget-management.md#ac-04): 本書のSPEC-01〜03で具体化。
- [budget-management/AC-05](../../req/features/budget-management.md#ac-05): 本書のSPEC-01〜03で具体化。
- [budget-management/AC-06](../../req/features/budget-management.md#ac-06): 本書のSPEC-01〜03で具体化。
- [budget-management/AC-07](../../req/features/budget-management.md#ac-07): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。
