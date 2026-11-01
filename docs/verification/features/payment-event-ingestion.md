# 外部決済イベント連携 検証計画

- **バージョン**: v0.1.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/payment-event-ingestion.md) / [SPEC](../../spec/features/payment-event-ingestion.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/payment-event-ingestion.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| payment-event-ingestion/TC-01 | [AC-01](../../req/features/payment-event-ingestion.md#ac-01) | SPEC-01〜03 | apple_pay、amount ¥1,280、JPY、固定spent_at、店舗セブン | URL/POSTの両経路で正規化 | 整数1280・source apple_pay、店舗をメモ、食費カテゴリへ1件保存 | 単体/結合 |
| payment-event-ingestion/TC-02 | [AC-02](../../req/features/payment-event-ingestion.md#ac-02) | SPEC-01〜03 | 同一source/外部ID、IDなし同額同店で±180秒と181秒 | 再送・並列送信 | ID再送は1件、180秒まで重複、181秒は別件。IDなし同時送信も1件 | 結合/API |
| payment-event-ingestion/TC-03 | [AC-03](../../req/features/payment-event-ingestion.md#ac-03) | SPEC-01〜03 | 背景APIで新規明細を作成、ローカルに未反映 | アプリ起動して同期 | 同IDの明細がローカル・日次・履歴に各1件、二重登録なし | E2E |
| payment-event-ingestion/TC-04 | [AC-04](../../req/features/payment-event-ingestion.md#ac-04) | SPEC-01〜03 | amount 0/負数/上限超過/文字列、USD、不正日時 | POSTとURLで取り込み | 不正は保存0件、API400/URLエラー。金額1と上限は成功 | 単体/API |
| payment-event-ingestion/TC-05 | [AC-05](../../req/features/payment-event-ingestion.md#ac-05) | SPEC-01〜03 | 既知店舗・不明店舗・分類先カテゴリ削除済み | 分類して保存 | 交通/日用品/食費の優先順で有効ID、不明・削除済みは未分類 | 単体/結合 |
| payment-event-ingestion/TC-06 | [AC-06](../../req/features/payment-event-ingestion.md#ac-06) | SPEC-01〜03 | iOS実機ロック中、ショートカット設定済み、オンライン/オフライン | 取引オートメーションからGET/POST | オンラインでアプリ前面化せず保存。オフラインは失敗案内、成功扱いしない | 手動実機 |
| payment-event-ingestion/TC-07 | [AC-07](../../req/features/payment-event-ingestion.md#ac-07) | SPEC-01〜03 | 通知許可/拒否、重複/成功/失敗の各応答 | 取り込み、通知タップ、対象を削除後に通知タップ | 状態を区別。成功時許可なら通知、拒否でも保存。通知は該当編集、削除済みは案内 | Widget/実機 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。
