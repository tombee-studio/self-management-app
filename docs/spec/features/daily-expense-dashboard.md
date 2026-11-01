# 日次支出ダッシュボード 設計

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/daily-expense-dashboard.md)。設計の正本は本書。

## ドメイン境界・モデル

分類: **ExpenseLedgerの読み取りモデル（CQRSのQuery側）**。[共通アーキテクチャ](../architecture.md)と[ADR-0002](../../adr/0002-domain-contract-design.md)のDDD方針と[ADR-0003](../../adr/0003-cloud-api-only.md)のAWS配置に従う。全契約はv2.0.0。既存REQの業務範囲・AC番号を維持する。

| モデル | 所有・構成・制約 |
| :--- | :--- |
| DailyExpenseSummary（ReadModel） | LocalDate、TotalYen、カテゴリ内訳、ExpenseRow[]、projectionVersion、budgetHint |
| DailyExpenseQuery（値） | 表示日とTimeZone。集約のコピーではない |

### 不変条件・依存方向

- 合計と内訳は同一スナップショットから算出し、カテゴリ和=日次合計。
- Queryは集約・版・DomainEventOutboxを変更せず、取得失敗を0件成功へ読み替えない。

DailyExpenseQueryPort.fetch(LocalDate,TimeZone)、BudgetSummaryQueryPort、RemoteRefreshCoordinator。表示操作はQueryServiceから不変DTOを受ける。編集/削除はMANのCommandへ委譲する。

アプリの画面/ControllerはHTTP Port経由でLambdaを呼ぶ。以下の集約・Repository・QueryPort・UnitOfWorkはすべてサーバー側。クライアントにDB実装を配置しない。

### 公開契約

契約の成功・失敗・版・トランザクション・再試行の共通意味は[共通規則](../architecture.md#5-契約の共通規則)。Operationの引数型は上の値型/DTOとSPEC-01の項目定義を使い、DynamoDB項目型を公開しない。QueryのsnapshotIdとVersionは互換ではない。各HTTP入力/出力は公開SchemaのCommandRequest/QueryRequestと対応するResultを使用する。

<a id="dash-c01"></a>
#### DASH-C01: WatchDailySummary

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `WatchDailySummary{date,timeZone} → Result<DailyExpenseSummary>` |
| 事前条件 | 1970-01-01以降のLocalDate、有効なTimeZone |
| 成功後の保証・変更範囲 | 同じスナップショットの明細・合計・内訳を返す。0件は合計0、比率0。読取専用 |
| 失敗 | ValidationFailed/StorageFailure |
| 冪等性・再試行 | 同じsnapshotなら同値。再購読で書込・通知を起こさない |
| 対応REQ | [AC-01](../../req/features/daily-expense-dashboard.md#ac-01), [AC-02](../../req/features/daily-expense-dashboard.md#ac-02), [AC-04](../../req/features/daily-expense-dashboard.md#ac-04), [AC-05](../../req/features/daily-expense-dashboard.md#ac-05), [AC-06](../../req/features/daily-expense-dashboard.md#ac-06) |

<a id="dash-c02"></a>
#### DASH-C02: RefreshDailyProjection

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `RefreshDailyProjection{date,timeZone,afterReadGeneration?} → Result<DailyExpenseSummary>` |
| 事前条件 | 日付有効。変更通知はcommit後に到着 |
| 成功後の保証・変更範囲 | 変更応答のreadGeneration以降で再取得し、古い応答で新しい表示を上書きしない。通信失敗時もメモリ内の前回表示維持 |
| 失敗 | StorageFailure/TransportFailure |
| 冪等性・再試行 | 重複イベントは同じ版の射影を二重加算しない |
| 対応REQ | [AC-03](../../req/features/daily-expense-dashboard.md#ac-03), [AC-06](../../req/features/daily-expense-dashboard.md#ac-06) |

## SPEC-01: 表示・集計

SCR-001。起動時は今日、前日・翌日・日付ピッカー・今日へ戻るで選択日を変更する。日付は1970-01-01以降、未来日も許可。日次合計、カテゴリ内訳、予算の日次目安、明細、追加ボタンを表示する。

集計対象は指定timeZoneのの日界`[選択日00:00, 翌日00:00)`をUTCへ変換した範囲。合計はamountの整数和。カテゴリは金額降順、同額ならsortOrder・ID順。割合は合計が正の場合のみ`カテゴリ額/日次合計`、0件では0%とする。表示の丸めで割合の合計が100%からずれても金額合計を丸めない。予算値は[予算](budget-management.md)の家計期間サマリーを参照し、日次実績と予算期間実績を別ラベルにする。

明細はspentAt降順・ID降順、カテゴリ・金額・メモ・時刻・支払い方法を表示する。0件は0円と追加導線。読み込み中はインジケーター、失敗は再試行。明細タップは編集、スワイプは[手動支出](manual-expense-crud.md)のAPI確定後の削除・応答後5秒Undoへ委譲する。

## SPEC-02: 構成・データフロー

DailyExpenseDashboardScreen → DailyExpenseQueryService → DailyExpenseQueryPort。LambdaDailyExpenseQueryAdapterがExpenses/Categoriesから射影し、集約EntityをUIへ公開しない。


幅840以上は左ペインに日付・サマリー・内訳、右に明細と選択中のインライン編集。600以上840未満はサマリー・内訳を横並び、600未満は縦に並べ、いずれもスクロールで同じ内容を提供する。親の選択日と編集対象をProviderで保持し、リサイズで状態を初期化しない。

## SPEC-03: エラー・理由

APIの失敗を0件にしない。選択日を保持し再試行する。金額表示は¥#,##0、折り返し・縮小で欠けを防ぐ。Pull-to-refreshは表示対象APIを再取得する。通信失敗ではプロセスメモリ内の前回表示に未更新を表示する。

## REQ対応・検証入口

- [daily-expense-dashboard/AC-01](../../req/features/daily-expense-dashboard.md#ac-01): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-02](../../req/features/daily-expense-dashboard.md#ac-02): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-03](../../req/features/daily-expense-dashboard.md#ac-03): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-04](../../req/features/daily-expense-dashboard.md#ac-04): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-05](../../req/features/daily-expense-dashboard.md#ac-05): 本書のSPEC-01〜03で具体化。
- [daily-expense-dashboard/AC-06](../../req/features/daily-expense-dashboard.md#ac-06): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。

## 契約検証・実装への移行

[機能別検証計画](../../verification/features/daily-expense-dashboard.md)のTC-R3-CTで公開契約ごとの前提違反・成功保証・不変条件・失敗時副作用・再試行を検証する。既存SPEC-01〜03の業務/画面条件を契約の詳細規則として維持する。既存実装と途中の変更は移行元であり、本設計に適合済みとは扱わない。

## API版3への適用

保存・参照の配置、requestId、通信失敗、Undo期限は[共通アーキテクチャ](../architecture.md)に従う。表示・ドラフトはメモリのみで、端末内DBへの保存・参照・移行を設計に含めない。HTTP公開形式は[契約一覧](../contracts/README.md)。
