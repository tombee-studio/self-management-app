# クラウドデータアクセス 検証計画

- **バージョン**: v2.1.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応: [REQ](../../req/features/aws-cloud-database-sync.md) / [SPEC](../../spec/features/aws-cloud-database-sync.md)、[共通方針](../../spec/architecture.md)、[ADR-0003](../../adr/0003-cloud-api-only.md)。計画確定と実施結果を区別する。

## 範囲・前提・方法

全ACと現行公開契約を必須とする。API fakeの成功/400/409/500/切断/commit後応答喪失、2端末、古いexpectedVersion、HTTP/HTTPS URL、起動・復帰4/5秒・明示更新、稼働/予算通知構成を用意する。

業務データは隔離AWS環境またはDynamoDB provider代替で初期化し、端末DBを使わない。固定時計・IANA TimeZone・HTTP fake・通知fakeを注入する。アプリの単体/Widget、サーバーのDomain/Handler、DynamoDB原子性、共通fixtureによるHTTP consumer/providerを分ける。実機・通知・費用の確認は該当ACで必須とし、環境未準備は未実施。

## 受け入れケース

| ケースID | 対応REQ | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| aws-cloud-database-sync/TC-R3-AC-01 | [AC-01](../../req/features/aws-cloud-database-sync.md#ac-01) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 通信失敗時はエラーと再試行を表示し、入力とセッション内の直前表示を保持する。未取得データのオフライン参照・保存は提供しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| aws-cloud-database-sync/TC-R3-AC-02 | [AC-02](../../req/features/aws-cloud-database-sync.md#ac-02) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 追加・更新・削除はAWS API確定後に成功とし、同じ要求IDの再送で二重更新しない。応答喪失時は結果不明として確認/再送できる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| aws-cloud-database-sync/TC-R3-AC-03 | [AC-03](../../req/features/aws-cloud-database-sync.md#ac-03) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 削除済み明細は通常の取得結果に含めず、許可期間内の取り消しで同じID・内容に戻る。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| aws-cloud-database-sync/TC-R3-AC-04 | [AC-04](../../req/features/aws-cloud-database-sync.md#ac-04) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 起動・復帰・明示更新・変更成功後に必要な画面データをAPI取得する。自動同期ON/OFFとPush/Pullは提供しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| aws-cloud-database-sync/TC-R3-AC-05 | [AC-05](../../req/features/aws-cloud-database-sync.md#ac-05) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 取得/保存中・成功・失敗・結果不明を区別し、失敗で最終成功日時を更新しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| aws-cloud-database-sync/TC-R3-AC-06 | [AC-06](../../req/features/aws-cloud-database-sync.md#ac-06) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 更新競合はサーバーの集約版で検出し、古い版は拒否して入力を保持し最新版の確認を案内する。端末時計で上書き優先度を決めない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| aws-cloud-database-sync/TC-R3-AC-07 | [AC-07](../../req/features/aws-cloud-database-sync.md#ac-07) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 支出・カテゴリ・カテゴリ配分・予算をAWSに保存し、カテゴリ廃止時の未分類化と配分削除が一体で可視化され、支出合計が変わらない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| aws-cloud-database-sync/TC-R3-AC-08 | [AC-08](../../req/features/aws-cloud-database-sync.md#ac-08) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 月額500円を運用目標とし、費用通知と計測条件を構成へ記録する。通知は課金停止や上限保証を意味しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |

## 公開契約ケース

| ケースID | 契約 | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| aws-cloud-database-sync/TC-R3-CT-06 | [SYN-C06](../../spec/features/aws-cloud-database-sync.md#syn-c06) | ValidateCostConfigurationの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| aws-cloud-database-sync/TC-R3-CT-08 | [SYN-C08](../../spec/features/aws-cloud-database-sync.md#syn-c08) | RefreshRemoteDataの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| aws-cloud-database-sync/TC-R3-CT-09 | [SYN-C09](../../spec/features/aws-cloud-database-sync.md#syn-c09) | SendRemoteCommandの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| aws-cloud-database-sync/TC-R3-CT-10 | [SYN-C10](../../spec/features/aws-cloud-database-sync.md#syn-c10) | ConfigureConnectionの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |

## 旧ケースの追跡

旧版のケースを改訂後の合格として流用しない。旧手順・期待値・IDはGitコミット231a698以前で保持する。今回のTC-R3は新しい期待値で再実施する。

| 旧ID | 現行の対応 | 理由 |
| :--- | :--- | :--- |
| aws-cloud-database-sync/TC-01 | TC-R3-AC-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-02 | TC-R3-AC-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-03 | TC-R3-AC-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-04 | TC-R3-AC-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-05 | TC-R3-AC-05 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-06 | TC-R3-AC-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-07 | TC-R3-AC-07 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-08 | TC-R3-AC-08 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-09 | 廃止（端末DB移行なし）。クラウド移行はTC-R3-ARCH-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-CT-01 | TC-R3-CT-08 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-CT-02 | TC-R3-CT-09 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-CT-03 | 廃止（Replicaなし） | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-CT-04 | TC-R3-CT-08/09 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-CT-05 | 廃止（端末DB移行なし） | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-CT-06 | TC-R3-CT-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| aws-cloud-database-sync/TC-CT-07 | 廃止（Pullなし。HTTP Queryは共通TC-R3-ARCH-05/07） | ARCH-02によるAPI経由への変更。旧合格は継承しない |

## 実行と結果

Flutter側は`flutter test test/unit`と`flutter test test/widget test/widget_test.dart`。サーバー/HTTP/構成は実装後の対応テストコマンドとfixtureを結果文書へ記録する。既存のSQLiteテスト成功を本計画の合格にしない。APIは隔離環境、Terraformはvalidate/planで構成を確認し、この文書作業でapplyしない。

結果にはコミット/作業ツリーの対象、日時、OS・SDK・環境、ケースID、期待値/実測値、PASS/FAIL/未実施、応答と前後データ・イベント・receipt・画面証跡を記録する。実データを検証で変更しない。現時点は全ケース未実施。

## 2026-11-02 owner指定の検証環境

ownerの「実AWS・実機確認はiOSエミュレータ及びterraformのstg版との連動で確認」の指示を本計画の実行環境として適用する。今回のOS連動はiOS18.4 Simulator、バックエンドは独立したTerraform state・environment=stg・検証専用ownerのAPI Gateway/Lambda/DynamoDBを使う。既存ケースID・入力・業務期待値を維持する。AndroidのOS固有確認とWalletの実決済・物理ロック画面の特性はこの環境で測定したと扱わず、シミュレーターで実行した経路を証跡に明記する。課金はstgのAPI件数・Lambda実行・DynamoDB容量から記録し、月額実請求の完了と混同しない。

環境変更レビュー: PASS。ownerの明示指示、REQ/SPECの業務条件、隔離データ、既存ケースとの対応を確認。実装の要件・設計・機能数は変更しない。
