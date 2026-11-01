# 外部決済イベント連携 検証計画

- **バージョン**: v1.0.0
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

## ドメイン・公開契約の検証（ARCH-01）

[共通アーキテクチャ](../../spec/architecture.md)と機能書の契約を対象とする。既存TC-01以降を残し、以下のTC-CTを追加する。文書での契約定義・スキーマ例の検証をprovider/consumer実装の合格と混同しない。

基準fixture: amount=¥1,280/0/文字列、JPY/USD、不正日時、外部ID再送、IDなし同店同額±180/181秒、並列送信と期限切れleaseを用意。

| ケースID | 対応契約・要求 | 入力/前提・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| payment-event-ingestion/TC-CT-01 | [PAY-C01](../../spec/features/payment-event-ingestion.md#pay-c01)、REQ/ARCH-01、AC-01/04 | 上のfixtureからNormalizePaymentの正常入力と、事前条件「対応source=apple_pay。currency未指定はJPY、指定ならJPY」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「金額・日時・メモを値型へ変換。日時省略だけreceivedAt、指定不正は拒否。永続化なし」を実値/件数で確認。失敗はValidationFailed/UnsupportedSourceと一致し、未commitなら状態/版/Outbox不変。再試行は「同receivedAtと同入力で同じ値。DBや通知に副作用なし」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| payment-event-ingestion/TC-CT-02 | [PAY-C02](../../spec/features/payment-event-ingestion.md#pay-c02)、REQ/ARCH-01、AC-01/02/05 | 上のfixtureからIngestPaymentの正常入力と、事前条件「正常化済み値、所有者範囲、カテゴリLookup成立」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「台帳UoW内で重複判定。新規のみExpense作成・版・Outbox。未知/削除済み分類先は未分類」を実値/件数で確認。失敗はValidationFailed/Busy/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「外部ID再送はDuplicate、IDなしは180秒以内条件でDuplicate。新規IDを再採番して2件作らない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| payment-event-ingestion/TC-CT-03 | [PAY-C03](../../spec/features/payment-event-ingestion.md#pay-c03)、REQ/ARCH-01、AC-03/06 | 上のfixtureからSubmitBackgroundPaymentの正常入力と、事前条件「OpenAPIに一致、固定owner、POST本文優先」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「前面起動不要でクラウドへ保存。ローカルは後続同期で反映。lease中だけ重複検査〜保存を直列化」を実値/件数で確認。失敗は400入力/403owner/409Busy/500保存失敗と一致し、未commitなら状態/版/Outbox不変。再試行は「同外部IDで再試行。lease失効・再取得後も重複検査する」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| payment-event-ingestion/TC-CT-04 | [PAY-C04](../../spec/features/payment-event-ingestion.md#pay-c04)、REQ/ARCH-01、AC-07 | 上のfixtureからPresentIngestionResultの正常入力と、事前条件「Createdはcommit済み、expenseIdが存在」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「許可時にcommit後通知、拒否時SnackBar。通知タップはMAN編集を開き、削除済みは今日画面の案内」を実値/件数で確認。失敗は通知拒否はWarning。DB取得失敗はStorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「重複判定結果では成功通知を増やさない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |

Portのfakeと本番adapterへ同じcontract suiteを適用する。Queryは業務DB・版・Outboxの変更回数0、Commandはcommit後に限るイベント発行を監視する。同期は部分commit契約に従いACK済みだけが残り、cursor/lastSuccessは成功条件を満たした時だけ更新されることを確認する。UI・アイコンではDB参加を要求せず、純粋Policy/ビルド契約と実機証跡を確認する。

追加契約テストは今回未実施。途中実装の既存テスト結果を新契約への合格証跡として流用しない。
