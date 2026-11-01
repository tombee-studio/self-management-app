# クラウド同期 設計

- **バージョン**: v1.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/aws-cloud-database-sync.md)。設計の正本は本書。

## ドメイン境界・モデル

分類: **Replicationの技術的支援モデル・プロセスマネージャ**。[共通アーキテクチャ](../architecture.md)と[ADR-0002](../../adr/0002-domain-contract-design.md)に従う。全契約はv1.0.0。既存REQの業務範囲・AC番号を維持する。

| モデル | 所有・構成・制約 |
| :--- | :--- |
| OutboxChange（配送エンティティ） | entityKey、operation、payload、UpdateStamp、OutboxRevision。Expense等の集約自体ではない |
| SyncSession（永続プロセス状態） | idle/pushing/pulling/success/error、送信snapshot、pageToken、cursor、lastSuccess。業務集約を所有しない |

### 不変条件・依存方向

- ACKはentityKeyと送信revisionの完全一致だけを除去する。
- 未送信変更・削除を古いPullで上書きしない。全ページ成功までcursor/lastSuccessを進めない。
- Replica適用はDomainの不変条件を迂回せず、集約版を進めるが同じ変更を再Outbox化しない。

OutboxPort.snapshot/ack、SyncTransportPort.push/pull、ReplicaApplyPort、SyncSessionStore、ConnectionSettingsPort、Clock。HTTP/SQL/PreferencesをDomain/Applicationから直接importせずadapterに隔離する。

### 公開契約

契約の成功・失敗・版・トランザクション・再試行の共通意味は[共通規則](../architecture.md#5-契約の共通規則)。Operationの引数型は上の値型/DTOとSPEC-01の項目定義を使い、DB行型を公開しない。QueryのsnapshotIdとVersionは互換ではない。

<a id="syn-c01"></a>
#### SYN-C01: RequestSync

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `RequestSync{trigger:manual|startup|resume|mutation} → Result<SyncReport>` |
| 事前条件 | manual以外はautoSyncEnabled、resumeは前回開始から5秒以上、接続先HTTPS |
| 成功後の保証・変更範囲 | 同時実行を1本に合流。成功時だけ全工程成功時刻を表示。OFF時は自動通信0回。DBのローカル保存結果は巻き戻さない |
| 失敗 | ValidationFailed/TransportFailure/StorageFailure。無効トリガーはSkipped |
| 冪等性・再試行 | 同時要求は同じin-flight結果。実行中の新変更は次回snapshotへ残す |
| 対応REQ | [AC-01](../../req/features/aws-cloud-database-sync.md#ac-01), [AC-04](../../req/features/aws-cloud-database-sync.md#ac-04), [AC-05](../../req/features/aws-cloud-database-sync.md#ac-05) |

<a id="syn-c02"></a>
#### SYN-C02: PushOutbox

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `PushOutbox{ownerId,snapshot[]} → Result<PushReceipt{accepted[],conflicts[]}>` |
| 事前条件 | wire版2/schema妥当。snapshotは変更不可 |
| 成功後の保証・変更範囲 | server LWWを適用。古い/同時刻はserver値を返し、acceptedは送信revisionをecho。部分失敗でも未ACKを残す |
| 失敗 | ValidationFailed/OwnerMismatch/TransportFailure/StorageFailure |
| 冪等性・再試行 | 同じentity/updateStamp再送は追加効果なし。同時刻server優先を維持 |
| 対応REQ | [AC-02](../../req/features/aws-cloud-database-sync.md#ac-02), [AC-03](../../req/features/aws-cloud-database-sync.md#ac-03), [AC-06](../../req/features/aws-cloud-database-sync.md#ac-06) |

<a id="syn-c03"></a>
#### SYN-C03: ApplyPullPage

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ApplyPullPage{ownerId,page,cursorContext} → Result<PageReceipt>` |
| 事前条件 | owner/上限時刻/ページ位置が一致。未送信キーは保護対象 |
| 成功後の保証・変更範囲 | ページ単位UoWでReplicaApplyPort経由の状態/集約版更新。削除は該当UoWへ委譲。失敗はページを戻す。Outbox echoを起こさない |
| 失敗 | ValidationFailed/CursorInvalidated/StorageFailure |
| 冪等性・再試行 | 同ページ再送で二重加算・新たな配送イベントを作らない |
| 対応REQ | [AC-02](../../req/features/aws-cloud-database-sync.md#ac-02), [AC-03](../../req/features/aws-cloud-database-sync.md#ac-03), [AC-06](../../req/features/aws-cloud-database-sync.md#ac-06), [AC-07](../../req/features/aws-cloud-database-sync.md#ac-07) |

<a id="syn-c04"></a>
#### SYN-C04: CompleteSync

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `CompleteSync{sessionId,allPagesApplied,serverCursor} → Result<SyncReport>` |
| 事前条件 | Pushの応答を処理済み・全Pullページ適用済み |
| 成功後の保証・変更範囲 | cursor/lastSuccess/session成功を一体確定。途中失敗では直前成功値を保持 |
| 失敗 | StorageFailure/InvariantViolation |
| 冪等性・再試行 | 同sessionの完了再送は同じ成功値 |
| 対応REQ | [AC-05](../../req/features/aws-cloud-database-sync.md#ac-05), [AC-07](../../req/features/aws-cloud-database-sync.md#ac-07) |

<a id="syn-c05"></a>
#### SYN-C05: MigrateReplicationState

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `MigrateReplicationState{sourceDbVersion,legacyDeleteIds} → Result<MigrationReport>` |
| 事前条件 | 同期開始前。版1/2を識別しバックアップ可能 |
| 成功後の保証・変更範囲 | 版3へデータと集約版を保持して移行。DB取り込み成功後だけ旧設定キューを除去 |
| 失敗 | StorageFailure/UnsupportedVersion |
| 冪等性・再試行 | 再起動で再実行しても重複Outbox・データ欠落なし |
| 対応REQ | [AC-01](../../req/features/aws-cloud-database-sync.md#ac-01), [AC-02](../../req/features/aws-cloud-database-sync.md#ac-02) |

<a id="syn-c06"></a>
#### SYN-C06: ValidateCostConfiguration

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ValidateCostConfiguration{region,usageAssumptions,monthlyAlertUsd,email} → Result<CostConfigReport>` |
| 事前条件 | 正の閾値、通知先・計測条件あり |
| 成功後の保証・変更範囲 | 構成の妥当性だけを返す。月500円は目標で課金停止保証としない。AWSのapplyは実行しない |
| 失敗 | ValidationFailed |
| 冪等性・再試行 | 同構成は同じ報告。業務データへ副作用なし |
| 対応REQ | [AC-08](../../req/features/aws-cloud-database-sync.md#ac-08) |

<a id="syn-c07"></a>
#### SYN-C07: FetchPullPage

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `FetchPullPage{ownerId,since?,pageToken?} → Result<PullPage{records,nextPageToken?,serverCursor}>` |
| 事前条件 | ownerとwire版2が有効。pageTokenがowner・フィルタ・取得上限を固定している |
| 成功後の保証・変更範囲 | 同一取得上限内の変更だけを安定順で返す。LWWの更新時刻とキーを使う位置カーソルとし、更新によるoffsetずれで欠落させない。業務データを書き換えない |
| 失敗 | ValidationFailed/OwnerMismatch/CursorInvalidated/TransportFailure/StorageFailure |
| 冪等性・再試行 | 同pageTokenは同じ取得範囲。取得途中に更新された明細は次のsince範囲で必ず再取得できる |
| 対応REQ | AC-02/06/07 |

## SPEC-01: 設定・ライフサイクル

SCR-008。単一所有者用。既存AppConfigの接続先と固定所有者IDを初期値とし、接続先は設定で上書き可能。固定IDを認証情報として扱わず、多人数の公開サービスとして提供しない。エンドポイントはHTTPSのみ、空値・不正URLは保存不可。所有者ID変更は対象外で、読み取り専用表示に統一する。

起動、復帰（前回開始から5秒以上）、ローカル変更後に自動同期ONなら同期する。OFFでも変更はoutboxへ蓄積する。手動同期はON/OFFに関係なく実行可能。同時実行は1本にまとめ、実行中に追加された変更は次の同期へ残す。状態はidle/syncing/success/error、最終成功時刻はPushとPullが成功してから更新する。通信失敗時はローカル操作を巻き戻さず、次回トリガーと手動操作で再送する。

## SPEC-02: 変更追跡・順序・競合

ローカルは物理削除、クラウドはtombstone。SyncOutboxにentityType/id、operation、payload、updatedAt、revisionを保存する。追加・更新・削除・Undo・カテゴリ移行は本体変更と同じDBトランザクションでoutboxへ登録する。通常の全件Pushやis_synced列は使用しない。初回既存データはoutboxへ登録して送信する。

1. 送信開始時にoutboxのrevision付きスナップショットを取得する。
2. `POST /sync/push`で送信。サーバーはUTC更新時刻が新しい変更を採用。同時刻・古い変更はサーバー既存値を返す。
3. サーバーが応答したキーと送信revisionが現在も同じ場合に限ってoutboxから除去する。送信中の新しい変更を消さない。
4. `GET /sync/pull?since=...`で差分を取得。未送信の同一キーは保持し、その他はLWWでマージする。削除済み支出は物理削除、カテゴリ削除は未分類への移行と配分削除を行う。
5. Pullの全ページを適用後に返却カーソルを保存する。途中失敗はカーソルを進めない。

削除・Undoはそれぞれ新しいupdatedAt/revisionを持つ。UTCミリ秒の更新時刻は端末内で前回値以上（同じなら+1ms）を生成し、端末時計のずれは状態画面で診断する。複数端末が同時刻の場合はサーバー既存値を優先し、競合を成功レスポンスで通知する。未送信データを古いPullで上書きしない。

## SPEC-03: API・データモデル

Push JSONは`schema_version:2,user_id,expenses,categories,category_budgets,budget`。各Push ChangeにID・updated_at・is_deleted・送信revisionを持たせる。Pull/ConflictのRecordは送信元revisionを公開しない。支出にはamount/category_id/spent_at/memo/payment_method/source/external_tx_id。カテゴリにはname/icon_key/color_hex/sort_order/is_system。配分にはcategory_id/allocated_amount。予算はid=currentと設定値。削除ChangeはID・updated_at・is_deleted=true・送信revisionを必須とする。

応答は`accepted:[{entity_type,id,revision}],conflicts:[{entity_type,id,server_value}],server_cursor`。400は入力不正、所有者ID不一致は403、失敗は500。部分処理時は応答したキーだけをackする。既存v1との移行中はmerchant_nameをmemo、icon_nameをicon_keyへ読み替え、source欠落はexternal_tx_idの有無とpayment_methodを使って既存値を維持する。

Pullはexpenses/categories/category_budgets/budget、next_page_token、server_cursorを返す。sinceはサーバー発行カーソルで、更新時刻とIDを含む安定した境界を保持する。複数ページの取得中に新たな更新が起きても欠落させないよう取得開始時の上限時刻を固定する。サーバーのカテゴリ削除では紐づく明細の未分類化と配分削除を一つの業務変更として記録し、途中では削除完了を返さない。

## SPEC-04: 構成・移行・費用

DynamoDBは`iris_expenses`（PK=user_id, SK=expense_id）、`iris_categories`（PK=user_id, SK=category_id）、`iris_budgets`（PK=user_id, SK=budget_id）、`iris_category_budgets`（PK=user_id, SK=category_id）を用いる。各項目のupdated_atとis_deletedを保持し、tombstoneは今回の設計では自動消去しない。テーブル別の差分取得位置と上限時刻をページトークンに含める。決済の条件付きロックは`iris_sync_metadata`（PK=user_id, SK=lock_type）へ保存する。

CloudSyncScreen → RequestSyncHandler/SyncSession → OutboxPort/SyncTransportPort/ReplicaApplyPort。CloudSyncApiClientとDriftの実装はInfrastructureで、原子的整合はDomain/Applicationの契約に従う。 HTTP API/Lambda/DynamoDBはtransport adapter。Terraformでテーブル・API・Lambda・IAM・費用通知を管理する。端末側は共通スキーマ版3へ移行し、既存SharedPreferencesの削除保留IDをoutboxへ取り込む。DBへの取り込み成功後のみ旧キューを消し、移行中の同期を開始しない。

月500円は運用目標。AWS Budgetsの月額通知閾値はTerraform変数とし、リージョン・利用件数・保存量・通知先とともにデプロイ時に確認する。過去の無料枠・為替・月0円試算を確定値として使わない。通知は停止制御ではない。稼働・料金は実環境で別途検証する。

## SPEC-05: 異常系・理由

タイムアウト・失敗でoutboxと最終成功カーソルを失わない。JSON破損はマージせずエラー表示し、ローカル明細を保持する。カテゴリ欠落の支出は未分類へ退避する。DBと変更追跡を一体化し、全件Push・設定値だけの保留キューで起きる欠落を避ける。クラウド結果はローカル保存成功と別状態で表示する。

## REQ対応・検証入口

- [aws-cloud-database-sync/AC-01](../../req/features/aws-cloud-database-sync.md#ac-01): 本書のSPEC-01〜03およびSPEC-04〜05で具体化。
- [aws-cloud-database-sync/AC-02](../../req/features/aws-cloud-database-sync.md#ac-02): 本書のSPEC-01〜03およびSPEC-04〜05で具体化。
- [aws-cloud-database-sync/AC-03](../../req/features/aws-cloud-database-sync.md#ac-03): 本書のSPEC-01〜03およびSPEC-04〜05で具体化。
- [aws-cloud-database-sync/AC-04](../../req/features/aws-cloud-database-sync.md#ac-04): 本書のSPEC-01〜03およびSPEC-04〜05で具体化。
- [aws-cloud-database-sync/AC-05](../../req/features/aws-cloud-database-sync.md#ac-05): 本書のSPEC-01〜03およびSPEC-04〜05で具体化。
- [aws-cloud-database-sync/AC-06](../../req/features/aws-cloud-database-sync.md#ac-06): 本書のSPEC-01〜03およびSPEC-04〜05で具体化。
- [aws-cloud-database-sync/AC-07](../../req/features/aws-cloud-database-sync.md#ac-07): 本書のSPEC-01〜03およびSPEC-04〜05で具体化。
- [aws-cloud-database-sync/AC-08](../../req/features/aws-cloud-database-sync.md#ac-08): 本書のSPEC-01〜03およびSPEC-04〜05で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。

## 契約検証・実装への移行

[機能別検証計画](../../verification/features/aws-cloud-database-sync.md)のTC-CTで公開契約ごとの前提違反・成功保証・不変条件・失敗時副作用・再試行を検証する。既存SPEC-01〜03〜05の業務/画面条件を契約の詳細規則として維持する。既存実装と途中の変更は移行元であり、本設計に適合済みとは扱わない。
