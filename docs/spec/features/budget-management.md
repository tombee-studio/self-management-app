# 予算設定・管理 設計

- **バージョン**: v1.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/budget-management.md)。設計の正本は本書。

## ドメイン境界・モデル

分類: **Budgetingの更新モデル・計算ポリシー**。[共通アーキテクチャ](../architecture.md)と[ADR-0002](../../adr/0002-domain-contract-design.md)に従う。全契約はv1.0.0。既存REQの業務範囲・AC番号を維持する。

| モデル | 所有・構成・制約 |
| :--- | :--- |
| BudgetPlan（集約ルート） | OwnerId/current、月予算、開始日、通知設定、Allocation集合、AggregateVersion |
| Allocation（集約内エンティティ） | CategoryIdを識別子とする配分。独立Repositoryで直接更新しない |
| BudgetPeriod / BudgetSummary（値/ReadModel） | 家計期間、残額、暦日数、日次目安、予測。期間定義はCalendarMonthと分離 |

### 不変条件・依存方向

- 月予算・開始日・各配分はREQ範囲内。配分総額超過はWarningとして保存可能。
- BudgetPlanとAllocation・版・Outboxを一体保存し、通知SDKを集約から呼ばない。

BudgetRepository.load/save、BudgetPeriodExpenseQueryPort、BudgetCommitPort、NotificationPort、NotificationReceiptStore、Clock/TimeZone。保存Handlerと計算Policyを分離する。

### 公開契約

契約の成功・失敗・版・トランザクション・再試行の共通意味は[共通規則](../architecture.md#5-契約の共通規則)。Operationの引数型は上の値型/DTOとSPEC-01の項目定義を使い、DB行型を公開しない。QueryのsnapshotIdとVersionは互換ではない。

<a id="bud-c01"></a>
#### BUD-C01: ConfigureBudgetPlan

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ConfigureBudgetPlan{ownerId,expectedVersion,monthlyAmount,startDay,allocations,notificationEnabled,categoryBudgetEnabled} → Result<BudgetPlanView>` |
| 事前条件 | 版一致、金額・開始日・存在するカテゴリ参照が有効 |
| 成功後の保証・変更範囲 | Plan/配分/版/Outboxを一体保存。配分超過はWarning。成功後のみUI遷移 |
| 失敗 | ValidationFailed/VersionConflict/NotFound/StorageFailure |
| 冪等性・再試行 | 同値の適用済みはAlreadyApplied。失敗で画面入力を破棄しない |
| 対応REQ | [AC-01](../../req/features/budget-management.md#ac-01), [AC-03](../../req/features/budget-management.md#ac-03), [AC-04](../../req/features/budget-management.md#ac-04) |

<a id="bud-c02"></a>
#### BUD-C02: CalculateBudgetSummary

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `CalculateBudgetSummary{plan,asOfDate,timeZone,periodExpenses} → Result<BudgetSummary>` |
| 事前条件 | periodExpensesの期間がplan.resolvePeriodと一致、スナップショット世代一致 |
| 成功後の保証・変更範囲 | 暦日単位の残額・日次目安・予測を返す。最初3日間は予測警告なし。純粋関数 |
| 失敗 | ValidationFailed/SnapshotMismatch |
| 冪等性・再試行 | 同じ入力は同じ計算値。DB・通知に副作用なし |
| 対応REQ | [AC-02](../../req/features/budget-management.md#ac-02), [AC-05](../../req/features/budget-management.md#ac-05), [AC-06](../../req/features/budget-management.md#ac-06) |

<a id="bud-c03"></a>
#### BUD-C03: EvaluateBudgetThresholds

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `EvaluateBudgetThresholds{plan,summary} → Result<ThresholdDecision[]>` |
| 事前条件 | Plan版・期間・summaryの対応が一致 |
| 成功後の保証・変更範囲 | periodStart/thresholdのreceiptを一度だけ確定。commit後に80/100通知を順に試み、拒否でも台帳/Planは変更しない |
| 失敗 | SnapshotMismatch/StorageFailure。通知拒否はWarning |
| 冪等性・再試行 | 同期間・閾値の再評価は通知を増やさない。OFF中もreceiptを残す |
| 対応REQ | [AC-07](../../req/features/budget-management.md#ac-07) |

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

BudgetSettingsScreen → BudgetController → ConfigureBudgetPlanHandler → BudgetRepository/UoW。予算計算Policyは純粋、通知はReceipt確定後にNotificationPortへ委譲する。

以下はPortのInfrastructure実装と計算/表示Policyの具体化。具象DB・通知SDKをDomainへ持ち込まない。複数の物理テーブルに分かれていても、上の集約境界と契約単位で保存する。


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

## 契約検証・実装への移行

[機能別検証計画](../../verification/features/budget-management.md)のTC-CTで公開契約ごとの前提違反・成功保証・不変条件・失敗時副作用・再試行を検証する。既存SPEC-01〜03の業務/画面条件を契約の詳細規則として維持する。既存実装と途中の変更は移行元であり、本設計に適合済みとは扱わない。
