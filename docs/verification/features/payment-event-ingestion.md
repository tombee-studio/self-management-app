# 外部決済イベント連携 検証計画

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応: [REQ](../../req/features/payment-event-ingestion.md) / [SPEC](../../spec/features/payment-event-ingestion.md)、[共通方針](../../spec/architecture.md)、[ADR-0003](../../adr/0003-cloud-api-only.md)。計画確定と実施結果を区別する。

## 範囲・前提・方法

全ACと現行公開契約を必須とする。amount「¥1,280」/0/不正文字、JPY/USD、省略日時/不正日時、同外部ID、IDなし同店舗同額で179/180/181秒差、削除済み推定カテゴリ。アプリURLとShortcut GET/POSTを並列送信する。

業務データは隔離AWS環境またはDynamoDB provider代替で初期化し、端末DBを使わない。固定時計・IANA TimeZone・HTTP fake・通知fakeを注入する。アプリの単体/Widget、サーバーのDomain/Handler、DynamoDB原子性、共通fixtureによるHTTP consumer/providerを分ける。実機・通知・費用の確認は該当ACで必須とし、環境未準備は未実施。

## 受け入れケース

| ケースID | 対応REQ | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| payment-event-ingestion/TC-R3-AC-01 | [AC-01](../../req/features/payment-event-ingestion.md#ac-01) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 有効な決済データを共通形式へ変換し、日本円の整数支出として保存する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| payment-event-ingestion/TC-R3-AC-02 | [AC-02](../../req/features/payment-event-ingestion.md#ac-02) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 同一外部取引IDの再送を登録せず、IDなしでは記録元・金額・正規化店舗名が一致し決済日時差が3分以内の明細を重複とする。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| payment-event-ingestion/TC-R3-AC-03 | [AC-03](../../req/features/payment-event-ingestion.md#ac-03) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | ショートカットAPIによるバックグラウンド記録を次回API取得後に一覧へ反映する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| payment-event-ingestion/TC-R3-AC-04 | [AC-04](../../req/features/payment-event-ingestion.md#ac-04) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 金額・通貨・日時が不正なイベントは保存せず、失敗を呼び出し元へ返す。金額制約は手動支出と同じ。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| payment-event-ingestion/TC-R3-AC-05 | [AC-05](../../req/features/payment-event-ingestion.md#ac-05) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 店舗名のキーワードでカテゴリを推定し、一致しなければ未分類にする。削除済みカテゴリを参照しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| payment-event-ingestion/TC-R3-AC-06 | [AC-06](../../req/features/payment-event-ingestion.md#ac-06) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | ロック中の操作はアプリ前面起動を必要としないAPI経路を使い、通信失敗はショートカット側に通知する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |
| payment-event-ingestion/TC-R3-AC-07 | [AC-07](../../req/features/payment-event-ingestion.md#ac-07) | 上記fixtureの該当境界・正常/異常を実行。画面操作またはAPI要求の前後を記録し、再表示・再試行も実行 | 取り込み成功・重複・失敗を区別して表示する。アプリ経由の成功時は許可があればローカル通知を発行し、通知タップで該当明細の編集を開く。背景API経路の通知はショートカット側とする。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | Domain/HTTP/Widget、OS依存は両OS実機 |

## 公開契約ケース

| ケースID | 契約 | 入力・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| payment-event-ingestion/TC-R3-CT-01 | [PAY-C01](../../spec/features/payment-event-ingestion.md#pay-c01) | NormalizePaymentの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| payment-event-ingestion/TC-R3-CT-02 | [PAY-C02](../../spec/features/payment-event-ingestion.md#pay-c02) | IngestPaymentの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| payment-event-ingestion/TC-R3-CT-03 | [PAY-C03](../../spec/features/payment-event-ingestion.md#pay-c03) | SubmitBackgroundPaymentの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |
| payment-event-ingestion/TC-R3-CT-04 | [PAY-C04](../../spec/features/payment-event-ingestion.md#pay-c04) | PresentIngestionResultの契約表にある正常入力→同一要求再送→各事前条件を1つずつ破る入力→commit前障害を実行。Commandは同じrequestId/異なる入力も比較、Query/純粋操作は書込監視 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | fakeと実providerに共通fixture、公開HTTPはconsumer/provider双方 |

## 旧ケースの追跡

旧版のケースを改訂後の合格として流用しない。旧手順・期待値・IDはGitコミット231a698以前で保持する。今回のTC-R3は新しい期待値で再実施する。

| 旧ID | 現行の対応 | 理由 |
| :--- | :--- | :--- |
| payment-event-ingestion/TC-01 | TC-R3-AC-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-02 | TC-R3-AC-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-03 | TC-R3-AC-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-04 | TC-R3-AC-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-05 | TC-R3-AC-05 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-06 | TC-R3-AC-06 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-07 | TC-R3-AC-07 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-CT-01 | TC-R3-CT-01 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-CT-02 | TC-R3-CT-02 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-CT-03 | TC-R3-CT-03 | ARCH-02によるAPI経由への変更。旧合格は継承しない |
| payment-event-ingestion/TC-CT-04 | TC-R3-CT-04 | ARCH-02によるAPI経由への変更。旧合格は継承しない |

## 実行と結果

Flutter側は`flutter test test/unit`と`flutter test test/widget test/widget_test.dart`。サーバー/HTTP/構成は実装後の対応テストコマンドとfixtureを結果文書へ記録する。既存のSQLiteテスト成功を本計画の合格にしない。APIは隔離環境、Terraformはvalidate/planで構成を確認し、この文書作業でapplyしない。

結果にはコミット/作業ツリーの対象、日時、OS・SDK・環境、ケースID、期待値/実測値、PASS/FAIL/未実施、応答と前後データ・イベント・receipt・画面証跡を記録する。実データを検証で変更しない。現時点は全ケース未実施。
