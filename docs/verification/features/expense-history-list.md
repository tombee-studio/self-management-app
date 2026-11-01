# 支出履歴・過去一覧 検証計画

- **バージョン**: v2.1.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応: [REQ](../../req/features/expense-history-list.md) / [SPEC](../../spec/features/expense-history-list.md)、[共通方針](../../spec/architecture.md)、[ADR-0003](../../adr/0003-cloud-api-only.md)。計画確定と実施結果を区別する。

## 範囲・前提・方法

全ACと現行公開契約を必須とする。同日時を含む121明細、前月/当月/翌月、全期間、メモ「ＡＢＣ」「abc」「%」「_」、2カテゴリとmanual/apple_pay。50/50/21件を取得し、途中で別端末から追加・削除して世代を変える。

業務データは隔離AWS環境またはDynamoDB provider代替で初期化し、端末DBを使わない。固定時計・IANA TimeZone・HTTP fake・通知fakeを注入する。アプリの単体/Widget、サーバーのDomain/Handler、DynamoDB原子性、共通fixtureによるHTTP consumer/providerを分ける。実機・通知・費用の確認は該当ACで必須とし、環境未準備は未実施。

## 受け入れケース

| ケースID | 対応REQ | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| expense-history-list/TC-R3-AC-01 | [AC-01](../../req/features/expense-history-list.md#ac-01) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 表示月全体の金額合計と月間合計が一致する。検索時は月間合計と検索結果合計を区別して表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| expense-history-list/TC-R3-AC-02 | [AC-02](../../req/features/expense-history-list.md#ac-02) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 日別小計とその日の対象明細が一致し、明細は日時降順で表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| expense-history-list/TC-R3-AC-03 | [AC-03](../../req/features/expense-history-list.md#ac-03) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 期間・キーワード・カテゴリ・記録元をANDで絞り込み、0件時は案内と条件クリアを表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| expense-history-list/TC-R3-AC-04 | [AC-04](../../req/features/expense-history-list.md#ac-04) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | カレンダーの日付を選ぶとその日の明細と小計を表示し、対象月を変更した場合は日付選択を解除する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| expense-history-list/TC-R3-AC-05 | [AC-05](../../req/features/expense-history-list.md#ac-05) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | キーワードはメモ（店舗名を含む）を対象に英字の大小・全角半角を正規化した部分一致検索とする。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| expense-history-list/TC-R3-AC-06 | [AC-06](../../req/features/expense-history-list.md#ac-06) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | カテゴリ複数選択内はOR、未選択は全カテゴリ。記録元は全件・手動・Apple Payを選べる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| expense-history-list/TC-R3-AC-07 | [AC-07](../../req/features/expense-history-list.md#ac-07) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 全期間一覧は50件単位で追加取得し、追加取得で重複・欠落を生じさせない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |

## 公開契約ケース

| ケースID | 契約 | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| expense-history-list/TC-R3-CT-01 | [HIST-C01](../../spec/features/expense-history-list.md#hist-c01) | QueryHistoryの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| expense-history-list/TC-R3-CT-02 | [HIST-C02](../../spec/features/expense-history-list.md#hist-c02) | GetHistoryTotalsの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| expense-history-list/TC-R3-CT-03 | [HIST-C03](../../spec/features/expense-history-list.md#hist-c03) | SelectHistoryDateの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |

## 旧ケースの追跡

旧版のケースを改訂後の合格として流用しない。旧手順・期待値・IDはGitコミット231a698以前で保持する。今回のTC-R3は新しい期待値で再実施する。

| 旧ID | 現行の対応 | 理由 |
| :--- | :--- | :--- |
| expense-history-list/TC-01 | TC-R3-AC-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| expense-history-list/TC-02 | TC-R3-AC-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| expense-history-list/TC-03 | TC-R3-AC-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| expense-history-list/TC-04 | TC-R3-AC-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| expense-history-list/TC-05 | TC-R3-AC-05 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| expense-history-list/TC-06 | TC-R3-AC-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| expense-history-list/TC-07 | TC-R3-AC-07 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| expense-history-list/TC-CT-01 | TC-R3-CT-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| expense-history-list/TC-CT-02 | TC-R3-CT-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| expense-history-list/TC-CT-03 | TC-R3-CT-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |

## 実行と結果

Flutter側は`flutter test test/unit`と`flutter test test/widget test/widget_test.dart`。サーバー/HTTP/構成は実装後の対応テストコマンドとfixtureを結果文書へ記録する。既存のSQLiteテスト成功を本計画の合格にしない。APIは隔離環境、Terraformはvalidate/planで構成を確認し、この文書作業でapplyしない。

結果にはコミット/作業ツリーの対象、日時、OS・SDK・環境、ケースID、期待値/実測値、PASS/FAIL/未実施、応答と前後データ・イベント・receipt・画面証跡を記録する。実データを検証で変更しない。現時点は全ケース未実施。

## 2026-11-02 owner指定の検証環境

ownerの「実AWS・実機確認はiOSエミュレータ及びterraformのstg版との連動で確認」の指示を本計画の実行環境として適用する。今回のOS連動はiOS18.4 Simulator、バックエンドは独立したTerraform state・environment=stg・検証専用ownerのAPI Gateway/Lambda/DynamoDBを使う。既存ケースID・入力・業務期待値を維持する。AndroidのOS固有確認とWalletの実決済・物理ロック画面の特性はこの環境で測定したと扱わず、シミュレーターで実行した経路を証跡に明記する。課金はstgのAPI件数・Lambda実行・DynamoDB容量から記録し、月額実請求の完了と混同しない。

環境変更レビュー: PASS。ownerの明示指示、REQ/SPECの業務条件、隔離データ、既存ケースとの対応を確認。実装の要件・設計・機能数は変更しない。
