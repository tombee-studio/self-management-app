# クラウドデータアクセス 設計

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/aws-cloud-database-sync.md)。[共通アーキテクチャ](../architecture.md)、[ADR-0003](../../adr/0003-cloud-api-only.md)に従う。

## ドメイン境界・モデル

CloudAccessはアプリの技術的能力で、業務集約を所有しない。RequestStateはidle/loading/saving/success/error/unknownOutcome。ConnectionSettingsはHTTPS endpointと固定owner表示。RemoteCommandPort/RemoteQueryPort/ConnectionSettingsPort/Clockを使い、HTTPと設定保存をInfrastructureへ隔離する。端末内DB・同期ワーカー・Outbox・Replica適用を置かない。

## 公開契約

操作契約v2.0.0。共通の副作用・エラー・冪等性は[共通規則](../architecture.md#5-契約の共通規則)。

<a id="syn-c06"></a>
### SYN-C06: ValidateCostConfiguration

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ValidateCostConfiguration{region,usageAssumptions,monthlyAlertUsd,email} → Result<CostConfigReport>` |
| 事前条件 | 正の通知閾値・通知先・計測条件が有効 |
| 成功後の保証・変更範囲 | 費用構成だけ検査し、AWS applyや業務データ変更を行わない |
| 失敗 | ValidationFailed。通信失敗は入力保持 |
| 冪等性・再試行 | 同一入力で再試行。CommandはサーバーReceiptで重複排除、Queryと設定検査は業務状態変更なし |
| 対応REQ | AC-08 |

<a id="syn-c08"></a>
### SYN-C08: RefreshRemoteData

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `RefreshRemoteData{trigger:startup|resume|manual|mutation,resources} → Result<RefreshReport>` |
| 事前条件 | HTTPS接続先・有効リソース。resumeは前回取得開始から5秒以上 |
| 成功後の保証・変更範囲 | 同じ対象の実行中取得を合流。取得成功だけ最終成功日時更新。メモリ表示のみ置換 |
| 失敗 | ValidationFailed/TransportFailure/Busy。通信失敗は入力保持 |
| 冪等性・再試行 | 同一入力で再試行。CommandはサーバーReceiptで重複排除、Queryと設定検査は業務状態変更なし |
| 対応REQ | AC-01/04/05 |

<a id="syn-c09"></a>
### SYN-C09: SendRemoteCommand

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `SendRemoteCommand{requestId,operation,input} → Result<CommandResult>` |
| 事前条件 | 操作別入力とrequestIdが有効 |
| 成功後の保証・変更範囲 | API確定後だけ成功。タイムアウトはUnknownOutcome。再送では同じID/操作/入力を使う |
| 失敗 | ValidationFailed/VersionConflict/TransportFailure。通信失敗は入力保持 |
| 冪等性・再試行 | 同一入力で再試行。CommandはサーバーReceiptで重複排除、Queryと設定検査は業務状態変更なし |
| 対応REQ | AC-02/03/06/07 |

<a id="syn-c10"></a>
### SYN-C10: ConfigureConnection

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ConfigureConnection{endpoint} → Result<ConnectionView>` |
| 事前条件 | HTTPS URL、userinfoなし |
| 成功後の保証・変更範囲 | 接続先設定だけ保存。OwnerIdは変更不可。業務データは端末へ保存しない |
| 失敗 | ValidationFailed。通信失敗は入力保持 |
| 冪等性・再試行 | 同一入力で再試行。CommandはサーバーReceiptで重複排除、Queryと設定検査は業務状態変更なし |
| 対応REQ | AC-04/05 |

## 廃止契約の追跡

| 旧ID | 旧操作 | 現行の対応 |
| :--- | :--- | :--- |
| SYN-C01 | RequestSync | SYN-C08の画面再取得。自動同期ON/OFFは削除 |
| SYN-C02 | PushOutbox | SYN-C09と各業務Command。Push APIを削除 |
| SYN-C03 | ApplyPullPage | 廃止。端末にReplicaなし |
| SYN-C04 | CompleteSync | SYN-C08/09の要求状態管理。同期カーソルなし |
| SYN-C05 | MigrateReplicationState | 廃止。端末DB移行なし |
| SYN-C07 | FetchPullPage | 各業務Query。Pull APIを削除 |

## SPEC-01: 画面とライフサイクル

SCR-008はクラウド接続設定。組み込み接続先を初期値としHTTPS URLを上書き可能、所有者IDは読取専用。自動同期スイッチ・同期キュー・Push/Pull進捗を削除し、接続確認、表示の再取得、最終成功日時、通信結果を表示する。

起動/復帰/明示更新で表示対象のQueryを呼ぶ。保存後は応答のreadGeneration以降で必要画面を再取得する。別端末の変更は次回取得で見える。ネットワークなしはエラー、プロセスメモリ内の表示/入力は保持するが再起動後の復元を保証しない。

## SPEC-02: APIとサーバー処理

`POST /commands`はrequestId/operation/input、`POST /queries`はoperation/input、`GET /health`は接続確認、`GET/POST /payment`は決済取込。[OpenAPI](../contracts/openapi.json)と[共通Schema](../contracts/shared.schema.json)を使用する。schemaVersion=3。所有者はx-user-idか/paymentのuser_idで指定し、両方あるとき異なるならOwnerMismatch。未指定は400、許可外は403。識別子は認証資格ではない。

コマンドはApplication Handler → Domain Port → DynamoDB UnitOfWork。受信値だけで直接SDK更新せず、サーバーで全制約を再検証する。requestIdのReceipt・集約版CAS・世代更新・イベントを同時に確定する。更新日時はサーバーが付与する。

## SPEC-03: AWS構成・データモデル

API Gateway HTTP API → Lambda → DynamoDB。IAMはLambdaの必要テーブル/操作へのアクセスを許可する。アプリからDynamoDBへの直接アクセスはない。認証方式は本変更では追加せず、単一所有者・非公開サービスの制約を継承する。

DynamoDBの保存形式・世代/receipt・カテゴリ廃止の原子性は[SPEC](../SPEC.md#dynamodb-model)と共通方針に従う。TerraformはAPI・Lambda・IAM・テーブル・費用通知を管理する。既存TerraformとLambdaはまだ旧設計のため改修対象。

## SPEC-04: 移行・費用

端末DBの自動移行・アップロード・消去は対象外。既存クラウドデータはバックアップと書込停止後にサーバー専用移行し、ID/件数/総額/カテゴリ対応を検証して版3 APIを有効化する。旧APIの混在書込を止める。失敗時はバックアップへ復帰する。

月額500円は運用目標。region/読取・書込件数/データ量/通知先/予算通知閾値をTerraform変数と計測証跡に記録する。全件検索と再取得のコストを含め、無料枠や為替の固定値で達成を保証しない。予算通知は課金停止ではない。

## SPEC-05: 異常系・検証

失敗確定と結果不明を区別する。結果不明は新requestIdにせず同じ入力で再送してReceiptを得る。古いexpectedVersionは409で最新版を案内する。破損したJSONを成功や空一覧にしない。再取得に失敗しても保存commitの成功を取り消さない。

[検証計画](../../verification/features/aws-cloud-database-sync.md)はAC-01〜08と現行4契約を検証する。旧同期ケースはGit履歴で追跡し、現在の合格として流用しない。
