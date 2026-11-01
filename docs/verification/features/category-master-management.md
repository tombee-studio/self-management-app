# カテゴリマスター管理 検証計画

- **バージョン**: v2.1.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応: [REQ](../../req/features/category-master-management.md) / [SPEC](../../spec/features/category-master-management.md)、[共通方針](../../spec/architecture.md)、[ADR-0003](../../adr/0003-cloud-api-only.md)。計画確定と実施結果を区別する。

## 範囲・前提・方法

全ACと現行公開契約を必須とする。空Catalog、既定9件、名称空白/20/21graphemeと「ＡＢＣ」「abc」、重複順序、未分類、カテゴリAに1000明細と配分を用意。廃止と支出登録を同時実行し、取引失敗を注入する。

業務データは隔離AWS環境またはDynamoDB provider代替で初期化し、端末DBを使わない。固定時計・IANA TimeZone・HTTP fake・通知fakeを注入する。アプリの単体/Widget、サーバーのDomain/Handler、DynamoDB原子性、共通fixtureによるHTTP consumer/providerを分ける。実機・通知・費用の確認は該当ACで必須とし、環境未準備は未実施。

## 受け入れケース

| ケースID | 対応REQ | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| category-master-management/TC-R3-AC-01 | [AC-01](../../req/features/category-master-management.md#ac-01) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 有効な名称・アイコン・色を保存し、再起動後に復元する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| category-master-management/TC-R3-AC-02 | [AC-02](../../req/features/category-master-management.md#ac-02) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 並び替えた順序を一覧と支出入力へ反映する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| category-master-management/TC-R3-AC-03 | [AC-03](../../req/features/category-master-management.md#ac-03) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 使用中カテゴリ削除時に紐づく支出を未分類へ移し、未分類は編集・削除できない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| category-master-management/TC-R3-AC-04 | [AC-04](../../req/features/category-master-management.md#ac-04) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 名称は前後空白を除いて1〜20文字。空白のみと同名重複を拒否する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| category-master-management/TC-R3-AC-05 | [AC-05](../../req/features/category-master-management.md#ac-05) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 移し替え・カテゴリ配分削除・カテゴリ削除が一体で成功または取り消され、支出合計は変わらない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| category-master-management/TC-R3-AC-06 | [AC-06](../../req/features/category-master-management.md#ac-06) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 初回起動で食費・日用品・交通費・カフェ・外食、衣服・美容、医療・健康、趣味・娯楽、住まい・通信・未分類を各1件生成する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |

## 公開契約ケース

| ケースID | 契約 | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| category-master-management/TC-R3-CT-01 | [CAT-C01](../../spec/features/category-master-management.md#cat-c01) | UpsertCategoryの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| category-master-management/TC-R3-CT-02 | [CAT-C02](../../spec/features/category-master-management.md#cat-c02) | ReorderCatalogの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| category-master-management/TC-R3-CT-03 | [CAT-C03](../../spec/features/category-master-management.md#cat-c03) | RetireCategoryの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| category-master-management/TC-R3-CT-04 | [CAT-C04](../../spec/features/category-master-management.md#cat-c04) | EnsureDefaultCatalogの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |

## 旧ケースの追跡

旧版のケースを改訂後の合格として流用しない。旧手順・期待値・IDはGitコミット231a698以前で保持する。今回のTC-R3は新しい期待値で再実施する。

| 旧ID | 現行の対応 | 理由 |
| :--- | :--- | :--- |
| category-master-management/TC-01 | TC-R3-AC-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| category-master-management/TC-02 | TC-R3-AC-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| category-master-management/TC-03 | TC-R3-AC-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| category-master-management/TC-04 | TC-R3-AC-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| category-master-management/TC-05 | TC-R3-AC-05 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| category-master-management/TC-06 | TC-R3-AC-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| category-master-management/TC-CT-01 | TC-R3-CT-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| category-master-management/TC-CT-02 | TC-R3-CT-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| category-master-management/TC-CT-03 | TC-R3-CT-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| category-master-management/TC-CT-04 | TC-R3-CT-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |

## 実行と結果

Flutter側は`flutter test test/unit`と`flutter test test/widget test/widget_test.dart`。サーバー/HTTP/構成は実装後の対応テストコマンドとfixtureを結果文書へ記録する。既存のSQLiteテスト成功を本計画の合格にしない。APIは隔離環境、Terraformはvalidate/planで構成を確認し、この文書作業でapplyしない。

結果にはコミット/作業ツリーの対象、日時、OS・SDK・環境、ケースID、期待値/実測値、PASS/FAIL/未実施、応答と前後データ・イベント・receipt・画面証跡を記録する。実データを検証で変更しない。現時点は全ケース未実施。

## 2026-11-02 owner指定の検証環境

ownerの「実AWS・実機確認はiOSエミュレータ及びterraformのstg版との連動で確認」の指示を本計画の実行環境として適用する。今回のOS連動はiOS18.4 Simulator、バックエンドは独立したTerraform state・environment=stg・検証専用ownerのAPI Gateway/Lambda/DynamoDBを使う。既存ケースID・入力・業務期待値を維持する。AndroidのOS固有確認とWalletの実決済・物理ロック画面の特性はこの環境で測定したと扱わず、シミュレーターで実行した経路を証跡に明記する。課金はstgのAPI件数・Lambda実行・DynamoDB容量から記録し、月額実請求の完了と混同しない。

環境変更レビュー: PASS。ownerの明示指示、REQ/SPECの業務条件、隔離データ、既存ケースとの対応を確認。実装の要件・設計・機能数は変更しない。
