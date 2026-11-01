# 支出の手動登録・編集・削除 検証計画

- **バージョン**: v2.1.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応: [REQ](../../req/features/manual-expense-crud.md) / [SPEC](../../spec/features/manual-expense-crud.md)、[共通方針](../../spec/architecture.md)、[ADR-0003](../../adr/0003-cloud-api-only.md)。計画確定と実施結果を区別する。

## 範囲・前提・方法

全ACと現行公開契約を必須とする。固定時計2026-11-01T03:00:00.000Z、cat_food/未分類、支出1280円。0/-1/99,999,999/100,000,000/小数、空/100/101graphemeメモ、1969/1970/未来日、四則計算・ゼロ除算を用意。版1→2と古い版1、explicit/swipe、Undo UI4.9/5秒・サーバー29.9/30秒を比較する。

業務データは隔離AWS環境またはDynamoDB provider代替で初期化し、端末DBを使わない。固定時計・IANA TimeZone・HTTP fake・通知fakeを注入する。アプリの単体/Widget、サーバーのDomain/Handler、DynamoDB原子性、共通fixtureによるHTTP consumer/providerを分ける。実機・通知・費用の確認は該当ACで必須とし、環境未準備は未実施。

## 受け入れケース

| ケースID | 対応REQ | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| manual-expense-crud/TC-R3-AC-01 | [AC-01](../../req/features/manual-expense-crud.md#ac-01) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 有効な入力を1件として保存し、再起動後に同じ内容を参照できる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| manual-expense-crud/TC-R3-AC-02 | [AC-02](../../req/features/manual-expense-crud.md#ac-02) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 編集・削除を一覧と集計へ反映し、削除をキャンセルした場合は明細を保持する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| manual-expense-crud/TC-R3-AC-03 | [AC-03](../../req/features/manual-expense-crud.md#ac-03) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 不正な入力を保存せず、明示削除の確認と保存失敗時の案内を表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| manual-expense-crud/TC-R3-AC-04 | [AC-04](../../req/features/manual-expense-crud.md#ac-04) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 金額は日本円の整数1〜99,999,999円。0・負数・上限超過・不正な計算結果は保存しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| manual-expense-crud/TC-R3-AC-05 | [AC-05](../../req/features/manual-expense-crud.md#ac-05) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | カテゴリは存在するIDを必須とし、初期選択は未分類。日時は1970-01-01以降で未来日を許可する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| manual-expense-crud/TC-R3-AC-06 | [AC-06](../../req/features/manual-expense-crud.md#ac-06) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | メモは任意で100文字以内。前後空白を除去し、改行を空白へ置換する。支払い方法は現金・Apple Pay・カード・電子マネー・その他から選ぶ。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| manual-expense-crud/TC-R3-AC-07 | [AC-07](../../req/features/manual-expense-crud.md#ac-07) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 連続登録後に金額とメモを空にし、日付・カテゴリ・支払い方法は保持する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| manual-expense-crud/TC-R3-AC-08 | [AC-08](../../req/features/manual-expense-crud.md#ac-08) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | スワイプ削除はAPI確定後に表示へ反映し、確定応答を受けてから5秒以内の元に戻す操作で元のID・内容を復元する。明示削除には取り消しを付けない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| manual-expense-crud/TC-R3-AC-09 | [AC-09](../../req/features/manual-expense-crud.md#ac-09) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 入力を変更した状態で閉じる場合は破棄確認し、保存失敗時は入力内容を保持する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |

## 公開契約ケース

| ケースID | 契約 | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| manual-expense-crud/TC-R3-CT-01 | [MAN-C01](../../spec/features/manual-expense-crud.md#man-c01) | RecordExpenseの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| manual-expense-crud/TC-R3-CT-02 | [MAN-C02](../../spec/features/manual-expense-crud.md#man-c02) | ModifyExpenseの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| manual-expense-crud/TC-R3-CT-03 | [MAN-C03](../../spec/features/manual-expense-crud.md#man-c03) | DeleteExpenseの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| manual-expense-crud/TC-R3-CT-04 | [MAN-C04](../../spec/features/manual-expense-crud.md#man-c04) | RestoreExpenseの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| manual-expense-crud/TC-R3-CT-05 | [MAN-C05](../../spec/features/manual-expense-crud.md#man-c05) | CloseExpenseDraftの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |

## 旧ケースの追跡

旧版のケースを改訂後の合格として流用しない。旧手順・期待値・IDはGitコミット231a698以前で保持する。今回のTC-R3は新しい期待値で再実施する。

| 旧ID | 現行の対応 | 理由 |
| :--- | :--- | :--- |
| manual-expense-crud/TC-01 | TC-R3-AC-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-02 | TC-R3-AC-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-03 | TC-R3-AC-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-04 | TC-R3-AC-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-05 | TC-R3-AC-05 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-06 | TC-R3-AC-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-07 | TC-R3-AC-07 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-08 | TC-R3-AC-08 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-09 | TC-R3-AC-09 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-CT-01 | TC-R3-CT-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-CT-02 | TC-R3-CT-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-CT-03 | TC-R3-CT-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-CT-04 | TC-R3-CT-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| manual-expense-crud/TC-CT-05 | TC-R3-CT-05 | ARCH-02によるAPI経由への変更。旧合格は継承しない |

## 実行と結果

Flutter側は`flutter test test/unit`と`flutter test test/widget test/widget_test.dart`。サーバー/HTTP/構成は実装後の対応テストコマンドとfixtureを結果文書へ記録する。既存のSQLiteテスト成功を本計画の合格にしない。APIは隔離環境、Terraformはvalidate/planで構成を確認し、この文書作業でapplyしない。

結果にはコミット/作業ツリーの対象、日時、OS・SDK・環境、ケースID、期待値/実測値、PASS/FAIL/未実施、応答と前後データ・イベント・receipt・画面証跡を記録する。実データを検証で変更しない。現時点は全ケース未実施。

## 2026-11-02 owner指定の検証環境

ownerの「実AWS・実機確認はiOSエミュレータ及びterraformのstg版との連動で確認」の指示を本計画の実行環境として適用する。今回のOS連動はiOS18.4 Simulator、バックエンドは独立したTerraform state・environment=stg・検証専用ownerのAPI Gateway/Lambda/DynamoDBを使う。既存ケースID・入力・業務期待値を維持する。AndroidのOS固有確認とWalletの実決済・物理ロック画面の特性はこの環境で測定したと扱わず、シミュレーターで実行した経路を証跡に明記する。課金はstgのAPI件数・Lambda実行・DynamoDB容量から記録し、月額実請求の完了と混同しない。

環境変更レビュー: PASS。ownerの明示指示、REQ/SPECの業務条件、隔離データ、既存ケースとの対応を確認。実装の要件・設計・機能数は変更しない。
