# 日次支出ダッシュボード 検証計画

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応: [REQ](../../req/features/daily-expense-dashboard.md) / [SPEC](../../spec/features/daily-expense-dashboard.md)、[共通方針](../../spec/architecture.md)、[ADR-0003](../../adr/0003-cloud-api-only.md)。計画確定と実施結果を区別する。

## 範囲・前提・方法

全ACと現行公開契約を必須とする。Asia/Tokyoの日界直前/直後の100円/200円、0件の日、同額カテゴリ、予算期間と暦月が異なる日付。遅延した前日応答と当日応答を逆順に返す。

業務データは隔離AWS環境またはDynamoDB provider代替で初期化し、端末DBを使わない。固定時計・IANA TimeZone・HTTP fake・通知fakeを注入する。アプリの単体/Widget、サーバーのDomain/Handler、DynamoDB原子性、共通fixtureによるHTTP consumer/providerを分ける。実機・通知・費用の確認は該当ACで必須とし、環境未準備は未実施。

## 受け入れケース

| ケースID | 対応REQ | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| daily-expense-dashboard/TC-R3-AC-01 | [AC-01](../../req/features/daily-expense-dashboard.md#ac-01) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 選択日の対象明細の金額合計と日次合計が一致する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| daily-expense-dashboard/TC-R3-AC-02 | [AC-02](../../req/features/daily-expense-dashboard.md#ac-02) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 対象明細が0件の日は合計0円と空状態を表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| daily-expense-dashboard/TC-R3-AC-03 | [AC-03](../../req/features/daily-expense-dashboard.md#ac-03) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 登録・編集・削除後、再起動や画面移動をせず合計・内訳・明細へ反映する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| daily-expense-dashboard/TC-R3-AC-04 | [AC-04](../../req/features/daily-expense-dashboard.md#ac-04) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 日付は端末ローカル時間で区切り、日界直前・直後の明細を別日に計上する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| daily-expense-dashboard/TC-R3-AC-05 | [AC-05](../../req/features/daily-expense-dashboard.md#ac-05) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | カテゴリ別金額の合計は日次合計と一致し、合計0円では割合計算による例外を発生させない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| daily-expense-dashboard/TC-R3-AC-06 | [AC-06](../../req/features/daily-expense-dashboard.md#ac-06) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | データ取得失敗時にエラーと再試行を表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |

## 公開契約ケース

| ケースID | 契約 | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| daily-expense-dashboard/TC-R3-CT-01 | [DASH-C01](../../spec/features/daily-expense-dashboard.md#dash-c01) | WatchDailySummaryの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| daily-expense-dashboard/TC-R3-CT-02 | [DASH-C02](../../spec/features/daily-expense-dashboard.md#dash-c02) | RefreshDailyProjectionの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |

## 旧ケースの追跡

旧版のケースを改訂後の合格として流用しない。旧手順・期待値・IDはGitコミット231a698以前で保持する。今回のTC-R3は新しい期待値で再実施する。

| 旧ID | 現行の対応 | 理由 |
| :--- | :--- | :--- |
| daily-expense-dashboard/TC-01 | TC-R3-AC-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| daily-expense-dashboard/TC-02 | TC-R3-AC-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| daily-expense-dashboard/TC-03 | TC-R3-AC-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| daily-expense-dashboard/TC-04 | TC-R3-AC-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| daily-expense-dashboard/TC-05 | TC-R3-AC-05 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| daily-expense-dashboard/TC-06 | TC-R3-AC-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| daily-expense-dashboard/TC-CT-01 | TC-R3-CT-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| daily-expense-dashboard/TC-CT-02 | TC-R3-CT-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |

## 実行と結果

Flutter側は`flutter test test/unit`と`flutter test test/widget test/widget_test.dart`。サーバー/HTTP/構成は実装後の対応テストコマンドとfixtureを結果文書へ記録する。既存のSQLiteテスト成功を本計画の合格にしない。APIは隔離環境、Terraformはvalidate/planで構成を確認し、この文書作業でapplyしない。

結果にはコミット/作業ツリーの対象、日時、OS・SDK・環境、ケースID、期待値/実測値、PASS/FAIL/未実施、応答と前後データ・イベント・receipt・画面証跡を記録する。実データを検証で変更しない。現時点は全ケース未実施。
