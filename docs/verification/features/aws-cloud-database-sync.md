# クラウド同期 検証計画

- **バージョン**: v0.1.0
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
| aws-cloud-database-sync/TC-09 | [AC-02](../../req/features/aws-cloud-database-sync.md#ac-02) | SPEC-01〜03・04〜05 | 版1DBとSharedPreferences旧削除キュー、移行途中に失敗 | 版2へ移行し再起動・再試行 | 既存ID・全明細保持、削除キューはDB成功後だけ除去。移行完了まで同期開始0回 | 結合 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。
