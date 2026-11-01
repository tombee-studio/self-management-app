# クラウド同期 検証計画

- **バージョン**: v1.0.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/aws-cloud-database-sync.md) / [SPEC](../../spec/features/aws-cloud-database-sync.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/aws-cloud-database-sync.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| aws-cloud-database-sync/TC-01 | [AC-01](../../req/features/aws-cloud-database-sync.md#ac-01) | SPEC-01〜03・04〜05 | ネットワーク失敗のfake API、ローカル明細 | オフラインで登録・編集・削除し再起動 | ローカル操作を完了、変更をoutboxに保持、明細を参照できる | 結合 |
| aws-cloud-database-sync/TC-02 | [AC-02](../../req/features/aws-cloud-database-sync.md#ac-02) | SPEC-01〜03・04〜05 | 端末Aの追加/更新/削除・端末B、失敗応答の再送 | A Push→B Pull、途中失敗後に再実行 | 両端末とサーバーが同じID/値/削除状態。成功ackだけ除去 | API/結合 |
| aws-cloud-database-sync/TC-03 | [AC-03](../../req/features/aws-cloud-database-sync.md#ac-03) | SPEC-01〜03・04〜05 | 削除outboxと古いサーバー明細、削除Pushを遅延 | Pull、次にUndoを送信。削除Pushと復元Pushの順も逆転 | 古い明細は復活せず、新updatedAt/revisionの復元だけ残る | 結合/API |
| aws-cloud-database-sync/TC-04 | [AC-04](../../req/features/aws-cloud-database-sync.md#ac-04) | SPEC-01〜03・04〜05 | fake clock、同期ON/OFF、起動・変更・4秒/5秒復帰 | 各トリガーを実行、OFFで手動同期 | ONで対象トリガーだけ通信、OFF自動通信0回、OFF手動は1回 | 単体/Widget |
| aws-cloud-database-sync/TC-05 | [AC-05](../../req/features/aws-cloud-database-sync.md#ac-05) | SPEC-01〜03・04〜05 | 前回成功カーソルC0、Push成功/Pull失敗、後に全成功 | 同期状態を表示 | 失敗ではC0・成功時刻を保持、全成功後だけ更新。syncing/error/successが区別される | 結合/Widget |
| aws-cloud-database-sync/TC-06 | [AC-06](../../req/features/aws-cloud-database-sync.md#ac-06) | SPEC-01〜03・04〜05 | 同IDを時刻T/T+1で更新、同時刻競合、送信中にrevision更新 | Push/Pull/ackを順序入替 | 新時刻優先・同時刻サーバー優先、古いackで新outboxを消さず未送信値を保持 | 結合/API |
| aws-cloud-database-sync/TC-07 | [AC-07](../../req/features/aws-cloud-database-sync.md#ac-07) | SPEC-01〜03・04〜05 | カテゴリAと紐づく明細・配分・予算、複数端末 | カテゴリ削除・同期、Pull複数ページ途中失敗 | 未分類へ移り配分削除、予算も一致。途中失敗でカーソル不変、再試行で欠落なし | 結合/API |
| aws-cloud-database-sync/TC-08 | [AC-08](../../req/features/aws-cloud-database-sync.md#ac-08) | SPEC-01〜03・04〜05 | Terraform設定、月予算通知先、リージョン・利用量条件 | terraform validateとplanを確認し通知設定を検証 | 通知閾値/宛先/計測条件を記録。月500円目標を課金上限保証と表示しない | 構成/手動 |
| aws-cloud-database-sync/TC-09 | [AC-02](../../req/features/aws-cloud-database-sync.md#ac-02) | SPEC-01〜03・04〜05 | 版1DBとSharedPreferences旧削除キュー、移行途中に失敗 | 版3へ移行し再起動・再試行（版1→2の既存移行を経由） | 既存ID・全明細保持、削除キューはDB成功後だけ除去。移行完了まで同期開始0回 | 結合 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。

## ドメイン・公開契約の検証（ARCH-01）

[共通アーキテクチャ](../../spec/architecture.md)と機能書の契約を対象とする。既存TC-01以降を残し、以下のTC-CTを追加する。文書での契約定義・スキーマ例の検証をprovider/consumer実装の合格と混同しない。

基準fixture: pending revision1→送信中2、同時刻LWW、ACK部分成功、Pull2ページ目失敗、OFF・manual、版1/2DBと旧削除IDを用意。

| ケースID | 対応契約・要求 | 入力/前提・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| aws-cloud-database-sync/TC-CT-01 | [SYN-C01](../../spec/features/aws-cloud-database-sync.md#syn-c01)、REQ/ARCH-01、AC-01/04/05 | 上のfixtureからRequestSyncの正常入力と、事前条件「manual以外はautoSyncEnabled、resumeは前回開始から5秒以上、接続先HTTPS」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「同時実行を1本に合流。成功時だけ全工程成功時刻を表示。OFF時は自動通信0回。DBのローカル保存結果は巻き戻さない」を実値/件数で確認。失敗はValidationFailed/TransportFailure/StorageFailure。無効トリガーはSkippedと一致し、未commitなら状態/版/Outbox不変。再試行は「同時要求は同じin-flight結果。実行中の新変更は次回snapshotへ残す」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| aws-cloud-database-sync/TC-CT-02 | [SYN-C02](../../spec/features/aws-cloud-database-sync.md#syn-c02)、REQ/ARCH-01、AC-02/03/06 | 上のfixtureからPushOutboxの正常入力と、事前条件「wire版2/schema妥当。snapshotは変更不可」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「server LWWを適用。古い/同時刻はserver値を返し、acceptedは送信revisionをecho。部分失敗でも未ACKを残す」を実値/件数で確認。失敗はValidationFailed/OwnerMismatch/TransportFailure/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「同じentity/updateStamp再送は追加効果なし。同時刻server優先を維持」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| aws-cloud-database-sync/TC-CT-03 | [SYN-C03](../../spec/features/aws-cloud-database-sync.md#syn-c03)、REQ/ARCH-01、AC-02/03/06/07 | 上のfixtureからApplyPullPageの正常入力と、事前条件「owner/上限時刻/ページ位置が一致。未送信キーは保護対象」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「ページ単位UoWでReplicaApplyPort経由の状態/集約版更新。削除は該当UoWへ委譲。失敗はページを戻す。Outbox echoを起こさない」を実値/件数で確認。失敗はValidationFailed/CursorInvalidated/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「同ページ再送で二重加算・新たな配送イベントを作らない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| aws-cloud-database-sync/TC-CT-04 | [SYN-C04](../../spec/features/aws-cloud-database-sync.md#syn-c04)、REQ/ARCH-01、AC-05/07 | 上のfixtureからCompleteSyncの正常入力と、事前条件「Pushの応答を処理済み・全Pullページ適用済み」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「cursor/lastSuccess/session成功を一体確定。途中失敗では直前成功値を保持」を実値/件数で確認。失敗はStorageFailure/InvariantViolationと一致し、未commitなら状態/版/Outbox不変。再試行は「同sessionの完了再送は同じ成功値」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| aws-cloud-database-sync/TC-CT-05 | [SYN-C05](../../spec/features/aws-cloud-database-sync.md#syn-c05)、REQ/ARCH-01、AC-01/02 | 上のfixtureからMigrateReplicationStateの正常入力と、事前条件「同期開始前。版1/2を識別しバックアップ可能」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「版3へデータと集約版を保持して移行。DB取り込み成功後だけ旧設定キューを除去」を実値/件数で確認。失敗はStorageFailure/UnsupportedVersionと一致し、未commitなら状態/版/Outbox不変。再試行は「再起動で再実行しても重複Outbox・データ欠落なし」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| aws-cloud-database-sync/TC-CT-06 | [SYN-C06](../../spec/features/aws-cloud-database-sync.md#syn-c06)、REQ/ARCH-01、AC-08 | 上のfixtureからValidateCostConfigurationの正常入力と、事前条件「正の閾値、通知先・計測条件あり」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「構成の妥当性だけを返す。月500円は目標で課金停止保証としない。AWSのapplyは実行しない」を実値/件数で確認。失敗はValidationFailedと一致し、未commitなら状態/版/Outbox不変。再試行は「同構成は同じ報告。業務データへ副作用なし」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| aws-cloud-database-sync/TC-CT-07 | [SYN-C07](../../spec/features/aws-cloud-database-sync.md#syn-c07)、REQ/ARCH-01、AC-02/06/07 | 上のfixtureからFetchPullPageの正常入力と、事前条件「ownerとwire版2が有効。pageTokenがowner・フィルタ・取得上限を固定している」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「同一取得上限内の変更だけを安定順で返す。LWWの更新時刻とキーを使う位置カーソルとし、更新によるoffsetずれで欠落させない。業務データを書き換えない」を実値/件数で確認。失敗はValidationFailed/OwnerMismatch/CursorInvalidated/TransportFailure/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「同pageTokenは同じ取得範囲。取得途中に更新された明細は次のsince範囲で必ず再取得できる」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |

Portのfakeと本番adapterへ同じcontract suiteを適用する。Queryは業務DB・版・Outboxの変更回数0、Commandはcommit後に限るイベント発行を監視する。同期は部分commit契約に従いACK済みだけが残り、cursor/lastSuccessは成功条件を満たした時だけ更新されることを確認する。UI・アイコンではDB参加を要求せず、純粋Policy/ビルド契約と実機証跡を確認する。

追加契約テストは今回未実施。途中実装の既存テスト結果を新契約への合格証跡として流用しない。

既存TC-09は同じケースIDを維持し、最終移行先をDB版2から版3へ更新した。旧手順はGitコミット81798ffで参照できる。中間版2のデータ保持とAggregateVersions/DomainEventOutbox/ReadProjectionStateの追加はTC-ARCH-05でも確認する。
