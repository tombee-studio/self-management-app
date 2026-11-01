# 支出履歴・過去一覧 検証計画

- **バージョン**: v0.1.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/expense-history-list.md) / [SPEC](../../spec/features/expense-history-list.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/expense-history-list.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| expense-history-list/TC-01 | [AC-01](../../req/features/expense-history-list.md#ac-01) | SPEC-01〜03 | 11月に1000/500、10月に200、メモ検索一致は11月500だけ | 11月表示後に検索 | 月間1500、結果1件500、10月200を含まない | 結合/Widget |
| expense-history-list/TC-02 | [AC-02](../../req/features/expense-history-list.md#ac-02) | SPEC-01〜03 | 同日100/200、同時刻の別ID、翌日300 | タイムライン表示・追加ページ | 当日小計300、翌日300。日時降順・同時刻ID降順を維持 | 結合 |
| expense-history-list/TC-03 | [AC-03](../../req/features/expense-history-list.md#ac-03) | SPEC-01〜03 | カテゴリ2種・source2種・メモ2種を組合せた8件 | 期間/キーワード/カテゴリ/sourceをAND、カテゴリ内ORで検索 | 条件表に一致するID集合と完全一致。0件は条件クリアを表示 | 結合/Widget |
| expense-history-list/TC-04 | [AC-04](../../req/features/expense-history-list.md#ac-04) | SPEC-01〜03 | 11/1・11/2の明細、11/1選択中 | カレンダー日付を選択し、12月へ移動 | 選択日の明細のみ表示。月移動で選択解除、11月明細を表示しない | Widget |
| expense-history-list/TC-05 | [AC-05](../../req/features/expense-history-list.md#ac-05) | SPEC-01〜03 | メモＡＢＣ店とabc店、検索abc、文字%と_を含む別メモ | 検索を入力し200ms進める | 英字・全角差を無視して2件一致、%/_はワイルドカードでなく文字扱い | 単体/結合 |
| expense-history-list/TC-06 | [AC-06](../../req/features/expense-history-list.md#ac-06) | SPEC-01〜03 | カテゴリA/B/C、source manual/apple_pay | カテゴリ未選択→A/B選択→手動を選択 | 未選択全件、A/Bのみ、さらにmanualのみ。paymentMethodは条件と混同しない | 結合 |
| expense-history-list/TC-07 | [AC-07](../../req/features/expense-history-list.md#ac-07) | SPEC-01〜03 | 同時刻境界を含む121件、固定ID | 50件ずつ取得、途中に先頭へ新規明細を追加して再購読 | 最終ID集合がDBと一致、重複なし。小計はページ件数に依存しない | 結合 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。
