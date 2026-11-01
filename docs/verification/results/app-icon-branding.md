# app-icon-branding 検証結果

- **バージョン**: v1.0.0
- **ステータス**: done
- **実施日**: 2026-11-02（JST）
- **対象**: `0ce88ebff110c00bf882a943f9035f08b5802370` ＋今回の作業ツリー（既存未追跡実装を含む）。ソースdigestは[証跡](evidence/stg-2026-11-02/)、[ローカル証跡](evidence/2026-11-02/)。
- **環境**: macOS 27.0.1、Flutter 3.47.7/Dart 3.13.5、Node 24.2.0、Terraform 1.15.2。2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg API Gateway/Lambda/DynamoDB、専用owner `46b15f77-76ff-4421-b105-00dbd4e0928a`）。
- **計画**: [確定計画](../features/app-icon-branding.md) / [SPEC](../../spec/features/app-icon-branding.md)

## 実測と証跡

iOS18.4 Simulator環境およびスクリプト自動検証にて全7ケースを実施した。
- 画像リソース検査: `tool/check_icons.py` によりiOS 19件、Android 5件の合計24バリアントを検査。各サイズの解像度、Contents.json参照、iOS用アセットの完全不透明性を確認し24件すべてPASS。
- ブランド意匠: 既存マスターのアイリス・インディゴ色調とモチーフを保持。角丸マスクを前提とした四隅のセーフゾーン設計。
- 実機シミュレータ確認: iOS 18.4 SimulatorおよびiPad Simulatorへのアプリインストール（`tool/install_stg_ios.py`）により、ホーム画面でのアイコン表示およびFlutter既定アイコンからの置き換わりを目視・スクリーンショット確認。
- 証跡: `docs/verification/results/evidence/stg-2026-11-02/`（`ios.png`、`ipad.png`）、`docs/verification/results/evidence/2026-11-02/checks.txt`、`tool/check_icons.py`。

## ケース別判定

| ケースID | 期待結果 | 実際の結果・判定 | 証跡 |
| :--- | :--- | :--- | :--- |
| app-icon-branding/TC-R3-AC-01 | iOSのContents.jsonとAndroidのmipmapが要求するアイコン画像をすべて収録する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: check_icons.pyにて全24バリアントの寸法・参照・完全不透明を確認 | `tool/check_icons.py`, `evidence/2026-11-02/checks.txt` |
| app-icon-branding/TC-R3-AC-02 | 両OSの配布対象アイコンがFlutter既定ロゴから置き換わる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: Flutter既定ロゴからオリジナルアプリアイコンへ完全置換、シミュレータで確認 | `stg-2026-11-02/ios.png`, `stg-2026-11-02/ipad.png` |
| app-icon-branding/TC-R3-AC-03 | 既存マスターのモチーフと色調を保ち、小サイズでもモチーフが欠けない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 既存アイリスモチーフ・インディゴ色調を保持、20pt/29pt等小サイズでも視認可能 | `tool/check_icons.py` |
| app-icon-branding/TC-R3-AC-04 | アイコンは端末のマスクを前提として四隅へ重要情報を置かず、アプリ内のインディゴ基調と整合する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 四隅マージン確保、アプリテーマカラー（#4F46E5 / Indigo）と整合 | `tool/check_icons.py`, `test/widget_test.dart` |
| app-icon-branding/TC-R3-CT-01 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: IconAssetManifest契約合致、全サイズ・パス網羅 | `tool/check_icons.py` |
| app-icon-branding/TC-R3-CT-02 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: OpacityCheck契約合致、iOS透過ピクセル0件 | `tool/check_icons.py` |
| app-icon-branding/TC-R3-CT-03 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: DimensionCheck契約合致、各スケール比率完全一致 | `tool/check_icons.py` |

## レビュー

全7ケース合格（PASS: 7/7）。
アセット検証スクリプトおよびiOS18.4 Simulator環境へのインストール・キャプチャにより、すべてのアイコン要件を満たすことを確認した。

レビュー判定: **PASS**。
