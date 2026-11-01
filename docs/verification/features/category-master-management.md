# カテゴリマスター管理 検証計画

- **バージョン**: v0.1.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/category-master-management.md) / [SPEC](../../spec/features/category-master-management.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/category-master-management.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| category-master-management/TC-01 | [AC-01](../../req/features/category-master-management.md#ac-01) | SPEC-01〜03 | カテゴリ新規、名称食材、許可アイコン、#EF4444 | 保存し再起動 | 名称・アイコン・色が一致 | 結合 |
| category-master-management/TC-02 | [AC-02](../../req/features/category-master-management.md#ac-02) | SPEC-01〜03 | A/B/Cの順序 | C/A/Bへ並べ替え | 管理一覧と支出フォームがC/A/B、DB sortOrderも一致 | Widget/結合 |
| category-master-management/TC-03 | [AC-03](../../req/features/category-master-management.md#ac-03) | SPEC-01〜03 | Aを参照する明細2件合計1500、未分類1件 | A削除、未分類の編集・削除も呼び出す | 2件とも未分類へ移り合計不変、未分類の変更はUI/Repository双方で拒否 | 結合 |
| category-master-management/TC-04 | [AC-04](../../req/features/category-master-management.md#ac-04) | SPEC-01〜03 | 名称空白、20/21grapheme、ＡとA | 保存 | 空白・21字・正規化重複を拒否、20字を保存 | 単体/結合 |
| category-master-management/TC-05 | [AC-05](../../req/features/category-master-management.md#ac-05) | SPEC-01〜03 | カテゴリに支出と配分、DBの途中処理で失敗注入 | 安全削除 | 本体/支出/配分/outboxすべてロールバック。成功時だけ全反映 | 結合 |
| category-master-management/TC-06 | [AC-06](../../req/features/category-master-management.md#ac-06) | SPEC-01〜03 | 空DBと既存DB | 初回起動、再起動、版1から移行 | 固定IDの標準9件が1件ずつ存在、既存カテゴリ・明細を失わない | 結合 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。
