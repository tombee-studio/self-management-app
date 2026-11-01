# アプリアイコン・ブランディング 設計

- **バージョン**: v0.4.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/app-icon-branding.md)。設計の正本は本書。

## SPEC-01: アセットと表示

マスターは`assets/icon/app_icon_master.png`、色調は`AppTheme`のインディゴを参照する。新しい絵柄は作らず、既存マスターの財布・支出管理のモチーフを維持して必要サイズへ出力する。四隅へ重要な図形・文字を置かず、OSのマスク後にモチーフが欠けないことを確認する。

iOSは`ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`のfilename/size/scaleを正とし、各filenameに指定されたピクセル数のPNGを配置する。配布用画像は不透明にする。Androidは`android/app/src/main/AndroidManifest.xml`のicon参照と既存mipmapリソースを正とし、密度ごとのPNGを収録する。既存にないadaptive iconの新方式導入は今回の完了条件にしない。

## SPEC-02: 更新・検査

変更が必要なときは既存マスターから同じモチーフを比率保持で縮小し、プラットフォーム指定寸法へ書き出す。生成方法・実行コマンド・対象ファイルは実装時の証跡へ記録する。マスターと派生PNGはリポジトリに置く。必要な寸法が未生成の場合は既定Flutterロゴで代用せず未完了として扱う。

## SPEC-03: 異常系・理由

ビルド設定が参照する画像欠落、寸法不一致、iOS配布画像の透過は検査エラーとする。小さいサイズでのモチーフ判別は代表実機のホーム画面で手動確認する。既存マスターを正本とすることでOS間で異なる絵柄になることを避ける。

## REQ対応・検証入口

- [app-icon-branding/AC-01](../../req/features/app-icon-branding.md#ac-01): 本書のSPEC-01〜03で具体化。
- [app-icon-branding/AC-02](../../req/features/app-icon-branding.md#ac-02): 本書のSPEC-01〜03で具体化。
- [app-icon-branding/AC-03](../../req/features/app-icon-branding.md#ac-03): 本書のSPEC-01〜03で具体化。
- [app-icon-branding/AC-04](../../req/features/app-icon-branding.md#ac-04): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。
