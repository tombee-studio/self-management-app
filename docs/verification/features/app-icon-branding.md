# アプリアイコン・ブランディング 検証計画

- **バージョン**: v0.1.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/app-icon-branding.md) / [SPEC](../../spec/features/app-icon-branding.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/app-icon-branding.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| app-icon-branding/TC-01 | [AC-01](../../req/features/app-icon-branding.md#ac-01) | SPEC-01〜03 | iOS Contents.jsonとAndroid manifest/mipmap、マスターPNG | 全参照filenameと指定寸法を機械検査 | 欠落0件・寸法不一致0件、iOS配布画像の透過なし | アセット検査 |
| app-icon-branding/TC-02 | [AC-02](../../req/features/app-icon-branding.md#ac-02) | SPEC-01〜03 | iOS/Android配布用ビルド | 実機へインストールしてホーム画面を見る | 両OSで既定Flutterロゴが残らない | 手動実機 |
| app-icon-branding/TC-03 | [AC-03](../../req/features/app-icon-branding.md#ac-03) | SPEC-01〜03 | マスターと小サイズ派生画像、代表実機 | モチーフと切れを比較 | 同じモチーフ・色調を保持し判別可能、欠けなし。画像証跡を記録 | 手動 |
| app-icon-branding/TC-04 | [AC-04](../../req/features/app-icon-branding.md#ac-04) | SPEC-01〜03 | OSの標準マスクとテーマ色 | ホーム画面・アプリ画面を比較 | 四隅に重要情報の欠落なし、インディゴ基調が整合 | 手動実機 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。
