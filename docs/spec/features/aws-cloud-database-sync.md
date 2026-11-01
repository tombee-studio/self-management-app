# クラウド同期 設計

- **バージョン**: v0.4.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/aws-cloud-database-sync.md)。設計の正本は本書。

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

Push JSONは`schema_version:2,user_id,expenses,categories,category_budgets,budget`。各エンティティにID・updated_at・is_deleted・送信revisionを持たせる。支出にはamount/category_id/spent_at/memo/payment_method/source/external_tx_id。カテゴリにはname/icon_key/color_hex/sort_order/is_system。配分にはcategory_id/allocated_amount。予算はid=currentと設定値。削除payloadはID・updated_at・is_deleted=trueでよい。

応答は`accepted:[{entity_type,id,revision}],conflicts:[{entity_type,id,server_value}],server_cursor`。400は入力不正、所有者ID不一致は403、失敗は500。部分処理時は応答したキーだけをackする。既存v1との移行中はmerchant_nameをmemo、icon_nameをicon_keyへ読み替え、source欠落はexternal_tx_idの有無とpayment_methodを使って既存値を維持する。

Pullはexpenses/categories/category_budgets/budget、next_page_token、server_cursorを返す。sinceはサーバー発行カーソルで、更新時刻とIDを含む安定した境界を保持する。複数ページの取得中に新たな更新が起きても欠落させないよう取得開始時の上限時刻を固定する。サーバーのカテゴリ削除では紐づく明細の未分類化と配分削除を一つの業務変更として記録し、途中では削除完了を返さない。

## SPEC-04: 構成・移行・費用

DynamoDBは`iris_expenses`（PK=user_id, SK=expense_id）、`iris_categories`（PK=user_id, SK=category_id）、`iris_budgets`（PK=user_id, SK=budget_id）、`iris_category_budgets`（PK=user_id, SK=category_id）を用いる。各項目のupdated_atとis_deletedを保持し、tombstoneは今回の設計では自動消去しない。テーブル別の差分取得位置と上限時刻をページトークンに含める。決済の条件付きロックは`iris_sync_metadata`（PK=user_id, SK=lock_type）へ保存する。

`CloudSyncScreen`/`CloudSyncStateNotifier` → `CloudSyncService` → `CloudSyncApiClient` → HTTP API/Lambda → DynamoDB。Terraformでテーブル・API・Lambda・IAM・費用通知を管理する。端末側は共通スキーマ版2へ移行し、既存SharedPreferencesの削除保留IDをoutboxへ取り込む。DBへの取り込み成功後のみ旧キューを消し、移行中の同期を開始しない。

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
