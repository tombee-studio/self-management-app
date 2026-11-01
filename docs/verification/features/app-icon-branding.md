# アプリアイコン・ブランディング 検証計画

- **バージョン**: v1.0.0
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

## ドメイン・公開契約の検証（ARCH-01）

[共通アーキテクチャ](../../spec/architecture.md)と機能書の契約を対象とする。既存TC-01以降を残し、以下のTC-CTを追加する。文書での契約定義・スキーマ例の検証をprovider/consumer実装の合格と混同しない。

基準fixture: 正常master/manifest、画像欠落・寸法不一致・透過PNG、同digestの2回生成、実機証跡未提供を用意。

| ケースID | 対応契約・要求 | 入力/前提・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| app-icon-branding/TC-CT-01 | [ICON-C01](../../spec/features/app-icon-branding.md#icon-c01)、REQ/ARCH-01、AC-01/02 | 上のfixtureからValidateIconManifestの正常入力と、事前条件「参照manifestと画像を読める」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「全参照先の存在・寸法・iOS透過を確認。不正を既定ロゴで代用して成功にしない」を実値/件数で確認。失敗はAssetMissing/DimensionMismatch/TransparencyViolation/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「読取専用。同じアセットは同じ機械判定」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| app-icon-branding/TC-CT-02 | [ICON-C02](../../spec/features/app-icon-branding.md#icon-c02)、REQ/ARCH-01、AC-01/03/04 | 上のfixtureからGenerateIconVariantsの正常入力と、事前条件「既存マスター・必要寸法が妥当、出力先が明示されている」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「比率保持で規定寸法へ出力し、失敗時に部分生成物を配布対象へ昇格しない。入力マスターは変更しない」を実値/件数で確認。失敗はValidationFailed/StorageFailureと一致し、未commitなら状態/版/Outbox不変。再試行は「同じマスターdigest/manifestなら同じ出力。新規画像生成はしない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| app-icon-branding/TC-CT-03 | [ICON-C03](../../spec/features/app-icon-branding.md#icon-c03)、REQ/ARCH-01、AC-02/03/04 | 上のfixtureからReviewInstalledIconの正常入力と、事前条件「対象OSの実機に同じbuildを導入し証跡あり」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「Flutterロゴ残存なし・モチーフ欠けなし・色調整合を記録。未実施をPASSにしない」を実値/件数で確認。失敗はEvidenceMissing/VisualMismatchと一致し、未commitなら状態/版/Outbox不変。再試行は「同buildの証跡に結び付け、別buildへ合格を流用しない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |

Portのfakeと本番adapterへ同じcontract suiteを適用する。Queryは業務DB・版・Outboxの変更回数0、Commandはcommit後に限るイベント発行を監視する。同期は部分commit契約に従いACK済みだけが残り、cursor/lastSuccessは成功条件を満たした時だけ更新されることを確認する。UI・アイコンではDB参加を要求せず、純粋Policy/ビルド契約と実機証跡を確認する。

追加契約テストは今回未実施。途中実装の既存テスト結果を新契約への合格証跡として流用しない。
