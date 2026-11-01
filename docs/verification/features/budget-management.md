# 予算設定・管理 検証計画

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応: [REQ](../../req/features/budget-management.md) / [SPEC](../../spec/features/budget-management.md)、[共通方針](../../spec/architecture.md)、[ADR-0003](../../adr/0003-cloud-api-only.md)。計画確定と実施結果を区別する。

## 範囲・前提・方法

全ACと現行公開契約を必須とする。月150000円、開始1/25/28/29日、0/上限/超過の金額と配分、2月/閏年/夏時間、経過1/3/4日、未来支出。支出119999→120000→150000、通知OFF/拒否/再起動を用意する。

業務データは隔離AWS環境またはDynamoDB provider代替で初期化し、端末DBを使わない。固定時計・IANA TimeZone・HTTP fake・通知fakeを注入する。アプリの単体/Widget、サーバーのDomain/Handler、DynamoDB原子性、共通fixtureによるHTTP consumer/providerを分ける。実機・通知・費用の確認は該当ACで必須とし、環境未準備は未実施。

## 受け入れケース

| ケースID | 対応REQ | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| budget-management/TC-R3-AC-01 | [AC-01](../../req/features/budget-management.md#ac-01) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 有効な予算設定を保存し、再起動・再表示後も復元する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| budget-management/TC-R3-AC-02 | [AC-02](../../req/features/budget-management.md#ac-02) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 開始日〜翌月開始日前日を1期間とし、その期間の実績から残額・日次目安を計算する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| budget-management/TC-R3-AC-03 | [AC-03](../../req/features/budget-management.md#ac-03) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 背景タップ・完了操作でキーボードを閉じ、保存成功後は元画面または今日へ戻る。保存失敗時は遷移しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| budget-management/TC-R3-AC-04 | [AC-04](../../req/features/budget-management.md#ac-04) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 月間総予算は1〜99,999,999円、開始日は1〜28。カテゴリ別配分は0〜99,999,999円とし、総額超過は警告して保存を許可する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| budget-management/TC-R3-AC-05 | [AC-05](../../req/features/budget-management.md#ac-05) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 残額は予算−期間実績、日次目安はmax(0,floor(残額÷当日を含む残り暦日数))とする。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| budget-management/TC-R3-AC-06 | [AC-06](../../req/features/budget-management.md#ac-06) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 着地予測はfloor(期間実績÷当日を含む経過暦日数×期間総暦日数)。最初の3日間は予測警告を表示しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| budget-management/TC-R3-AC-07 | [AC-07](../../req/features/budget-management.md#ac-07) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 通知有効時に期間内で80%到達・100%到達を各1回通知し、通知拒否時も記録・集計を継続する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |

## 公開契約ケース

| ケースID | 契約 | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| budget-management/TC-R3-CT-01 | [BUD-C01](../../spec/features/budget-management.md#bud-c01) | ConfigureBudgetPlanの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| budget-management/TC-R3-CT-02 | [BUD-C02](../../spec/features/budget-management.md#bud-c02) | CalculateBudgetSummaryの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| budget-management/TC-R3-CT-03 | [BUD-C03](../../spec/features/budget-management.md#bud-c03) | EvaluateBudgetThresholdsの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |

## 旧ケースの追跡

旧版のケースを改訂後の合格として流用しない。旧手順・期待値・IDはGitコミット231a698以前で保持する。今回のTC-R3は新しい期待値で再実施する。

| 旧ID | 現行の対応 | 理由 |
| :--- | :--- | :--- |
| budget-management/TC-01 | TC-R3-AC-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| budget-management/TC-02 | TC-R3-AC-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| budget-management/TC-03 | TC-R3-AC-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| budget-management/TC-04 | TC-R3-AC-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| budget-management/TC-05 | TC-R3-AC-05 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| budget-management/TC-06 | TC-R3-AC-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| budget-management/TC-07 | TC-R3-AC-07 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| budget-management/TC-CT-01 | TC-R3-CT-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| budget-management/TC-CT-02 | TC-R3-CT-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| budget-management/TC-CT-03 | TC-R3-CT-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |

## 実行と結果

Flutter側は`flutter test test/unit`と`flutter test test/widget test/widget_test.dart`。サーバー/HTTP/構成は実装後の対応テストコマンドとfixtureを結果文書へ記録する。既存のSQLiteテスト成功を本計画の合格にしない。APIは隔離環境、Terraformはvalidate/planで構成を確認し、この文書作業でapplyしない。

結果にはコミット/作業ツリーの対象、日時、OS・SDK・環境、ケースID、期待値/実測値、PASS/FAIL/未実施、応答と前後データ・イベント・receipt・画面証跡を記録する。実データを検証で変更しない。現時点は全ケース未実施。
