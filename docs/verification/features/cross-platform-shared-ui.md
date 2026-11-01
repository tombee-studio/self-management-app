# 共通UI・マルチデバイス対応 検証計画

- **バージョン**: v2.1.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応: [REQ](../../req/features/cross-platform-shared-ui.md) / [SPEC](../../spec/features/cross-platform-shared-ui.md)、[共通方針](../../spec/architecture.md)、[ADR-0003](../../adr/0003-cloud-api-only.md)。計画確定と実施結果を区別する。

## 範囲・前提・方法

全ACと現行公開契約を必須とする。iOS16/Android12以降、幅320/599/600/839/840/900、回転・リサイズ、SafeArea/キーボード、未保存入力、⌘N/⌘矢印/Esc、通信遅延を用意する。

業務データは隔離AWS環境またはDynamoDB provider代替で初期化し、端末DBを使わない。固定時計・IANA TimeZone・HTTP fake・通知fakeを注入する。アプリの単体/Widget、サーバーのDomain/Handler、DynamoDB原子性、共通fixtureによるHTTP consumer/providerを分ける。実機・通知・費用の確認は該当ACで必須とし、環境未準備は未実施。

## 受け入れケース

| ケースID | 対応REQ | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| cross-platform-shared-ui/TC-R3-AC-01 | [AC-01](../../req/features/cross-platform-shared-ui.md#ac-01) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 幅320・600・900論理ピクセルの代表画面で主要操作をスクロール等により利用できる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| cross-platform-shared-ui/TC-R3-AC-02 | [AC-02](../../req/features/cross-platform-shared-ui.md#ac-02) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 回転・リサイズで選択日・表示月・入力内容を失わない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| cross-platform-shared-ui/TC-R3-AC-03 | [AC-03](../../req/features/cross-platform-shared-ui.md#ac-03) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | iOS・Androidで同じ業務操作・表示内容を提供する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| cross-platform-shared-ui/TC-R3-AC-04 | [AC-04](../../req/features/cross-platform-shared-ui.md#ac-04) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | ナビゲーションは幅600未満で下部タブ、600以上840未満でNavigationRail、840以上でラベル付きサイドナビと2ペイン。新規フォームは600未満でBottomSheet、600以上で中央ダイアログ。840以上の既存明細編集は右ペイン内で行う。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| cross-platform-shared-ui/TC-R3-AC-05 | [AC-05](../../req/features/cross-platform-shared-ui.md#ac-05) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | SafeAreaとキーボード領域を避け、入力完了・背景・タブ操作でフォーカスを解除する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| cross-platform-shared-ui/TC-R3-AC-06 | [AC-06](../../req/features/cross-platform-shared-ui.md#ac-06) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 画面幅は向き名ではなく現在の論理ピクセル幅で判定する。840以上の日次画面は左にサマリー、右に明細・編集を表示し、⌘N・⌘←/→・Escで追加・日付移動・閉じるを操作できる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |

## 公開契約ケース

| ケースID | 契約 | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| cross-platform-shared-ui/TC-R3-CT-01 | [UI-C01](../../spec/features/cross-platform-shared-ui.md#ui-c01) | ResolveLayoutの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| cross-platform-shared-ui/TC-R3-CT-02 | [UI-C02](../../spec/features/cross-platform-shared-ui.md#ui-c02) | ReflowDraftの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| cross-platform-shared-ui/TC-R3-CT-03 | [UI-C03](../../spec/features/cross-platform-shared-ui.md#ui-c03) | HandleNavigationIntentの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |

## 旧ケースの追跡

旧版のケースを改訂後の合格として流用しない。旧手順・期待値・IDはGitコミット231a698以前で保持する。今回のTC-R3は新しい期待値で再実施する。

| 旧ID | 現行の対応 | 理由 |
| :--- | :--- | :--- |
| cross-platform-shared-ui/TC-01 | TC-R3-AC-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| cross-platform-shared-ui/TC-02 | TC-R3-AC-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| cross-platform-shared-ui/TC-03 | TC-R3-AC-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| cross-platform-shared-ui/TC-04 | TC-R3-AC-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| cross-platform-shared-ui/TC-05 | TC-R3-AC-05 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| cross-platform-shared-ui/TC-06 | TC-R3-AC-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| cross-platform-shared-ui/TC-CT-01 | TC-R3-CT-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| cross-platform-shared-ui/TC-CT-02 | TC-R3-CT-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| cross-platform-shared-ui/TC-CT-03 | TC-R3-CT-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |

## 実行と結果

Flutter側は`flutter test test/unit`と`flutter test test/widget test/widget_test.dart`。サーバー/HTTP/構成は実装後の対応テストコマンドとfixtureを結果文書へ記録する。既存のSQLiteテスト成功を本計画の合格にしない。APIは隔離環境、Terraformはvalidate/planで構成を確認し、この文書作業でapplyしない。

結果にはコミット/作業ツリーの対象、日時、OS・SDK・環境、ケースID、期待値/実測値、PASS/FAIL/未実施、応答と前後データ・イベント・receipt・画面証跡を記録する。実データを検証で変更しない。現時点は全ケース未実施。

## 2026-11-02 owner指定の検証環境

ownerの「実AWS・実機確認はiOSエミュレータ及びterraformのstg版との連動で確認」の指示を本計画の実行環境として適用する。今回のOS連動はiOS18.4 Simulator、バックエンドは独立したTerraform state・environment=stg・検証専用ownerのAPI Gateway/Lambda/DynamoDBを使う。既存ケースID・入力・業務期待値を維持する。AndroidのOS固有確認とWalletの実決済・物理ロック画面の特性はこの環境で測定したと扱わず、シミュレーターで実行した経路を証跡に明記する。課金はstgのAPI件数・Lambda実行・DynamoDB容量から記録し、月額実請求の完了と混同しない。

環境変更レビュー: PASS。ownerの明示指示、REQ/SPECの業務条件、隔離データ、既存ケースとの対応を確認。実装の要件・設計・機能数は変更しない。
