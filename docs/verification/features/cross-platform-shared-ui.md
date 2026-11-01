# 共通UI・マルチデバイス対応 検証計画

- **バージョン**: v0.1.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/cross-platform-shared-ui.md) / [SPEC](../../spec/features/cross-platform-shared-ui.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/cross-platform-shared-ui.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| cross-platform-shared-ui/TC-01 | [AC-01](../../req/features/cross-platform-shared-ui.md#ac-01) | SPEC-01〜03 | iOS/Android、幅320/600/900、縦横、キーボードあり | 主要4画面とフォームを操作 | 主要操作にスクロールで到達し、レイアウト例外・欠けなし | Widget/実機 |
| cross-platform-shared-ui/TC-02 | [AC-02](../../req/features/cross-platform-shared-ui.md#ac-02) | SPEC-01〜03 | 選択日11/2、履歴月10月、入力金額1280 | 回転と600/840境界を跨ぐリサイズ | 選択日・表示月・入力金額を保持 | Widget |
| cross-platform-shared-ui/TC-03 | [AC-03](../../req/features/cross-platform-shared-ui.md#ac-03) | SPEC-01〜03 | 同一データと日本語設定のiOS/Android | 登録・編集・集計・予算を同じ手順で実行 | DB内容・集計値・操作結果が一致 | E2E |
| cross-platform-shared-ui/TC-04 | [AC-04](../../req/features/cross-platform-shared-ui.md#ac-04) | SPEC-01〜03 | 幅599/600/839/840 | ナビとフォームを表示 | 順に下部/Rail/Rail/サイドナビ、フォームはSheet/Dialog/Dialog/Dialog（編集は2ペイン） | Widget |
| cross-platform-shared-ui/TC-05 | [AC-05](../../req/features/cross-platform-shared-ui.md#ac-05) | SPEC-01〜03 | SafeArea inset、キーボードviewInsets、予算入力中 | 背景/Done/タブで操作 | フォーカス解除、保存と閉じるが隠れず操作可能 | Widget/実機 |
| cross-platform-shared-ui/TC-06 | [AC-06](../../req/features/cross-platform-shared-ui.md#ac-06) | SPEC-01〜03 | 幅840、選択日、フォーム未保存、文字入力中 | ⌘N・⌘←/→・Escを操作 | 追加/日移動/破棄確認、文字入力中の矢印は日付を変えない。右ペインに編集 | Widget/実機 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。
