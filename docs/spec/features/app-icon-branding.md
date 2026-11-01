# アプリアイコン・ブランディング 設計

- **バージョン**: v1.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/app-icon-branding.md)。設計の正本は本書。

## ドメイン境界・モデル

分類: **BrandAssetsのビルド時技術的能力（業務集約なし）**。[共通アーキテクチャ](../architecture.md)と[ADR-0002](../../adr/0002-domain-contract-design.md)に従う。全契約はv1.0.0。既存REQの業務範囲・AC番号を維持する。

| モデル | 所有・構成・制約 |
| :--- | :--- |
| IconManifest / AssetSpec（値） | マスター・参照先・寸法・密度・透過要件・色調 |
| AssetValidationReport（結果） | 不足/寸法不一致/透過/モチーフ確認の項目別結果 |

### 不変条件・依存方向

- 既存マスターを正本とし、OS間で異なる絵柄を独自生成しない。
- アイコン検査は台帳・予算・同期DBへ依存しない。

AssetReaderPort、ImageTransformPort、BuildManifestPort。機械検査と実機の視認性確認を区別する。

### 公開契約

契約の成功・失敗・版・トランザクション・再試行の共通意味は[共通規則](../architecture.md#5-契約の共通規則)。Operationの引数型は上の値型/DTOとSPEC-01の項目定義を使い、DB行型を公開しない。QueryのsnapshotIdとVersionは互換ではない。

<a id="icon-c01"></a>
#### ICON-C01: ValidateIconManifest

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ValidateIconManifest{master,iosContents,androidManifest,assets[]} → Result<AssetValidationReport>` |
| 事前条件 | 参照manifestと画像を読める |
| 成功後の保証・変更範囲 | 全参照先の存在・寸法・iOS透過を確認。不正を既定ロゴで代用して成功にしない |
| 失敗 | AssetMissing/DimensionMismatch/TransparencyViolation/StorageFailure |
| 冪等性・再試行 | 読取専用。同じアセットは同じ機械判定 |
| 対応REQ | [AC-01](../../req/features/app-icon-branding.md#ac-01), [AC-02](../../req/features/app-icon-branding.md#ac-02) |

<a id="icon-c02"></a>
#### ICON-C02: GenerateIconVariants

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `GenerateIconVariants{master,manifest} → Result<AssetOutputs>` |
| 事前条件 | 既存マスター・必要寸法が妥当、出力先が明示されている |
| 成功後の保証・変更範囲 | 比率保持で規定寸法へ出力し、失敗時に部分生成物を配布対象へ昇格しない。入力マスターは変更しない |
| 失敗 | ValidationFailed/StorageFailure |
| 冪等性・再試行 | 同じマスターdigest/manifestなら同じ出力。新規画像生成はしない |
| 対応REQ | [AC-01](../../req/features/app-icon-branding.md#ac-01), [AC-03](../../req/features/app-icon-branding.md#ac-03), [AC-04](../../req/features/app-icon-branding.md#ac-04) |

<a id="icon-c03"></a>
#### ICON-C03: ReviewInstalledIcon

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ReviewInstalledIcon{buildId,platform,deviceEvidence} → Result<VisualReview>` |
| 事前条件 | 対象OSの実機に同じbuildを導入し証跡あり |
| 成功後の保証・変更範囲 | Flutterロゴ残存なし・モチーフ欠けなし・色調整合を記録。未実施をPASSにしない |
| 失敗 | EvidenceMissing/VisualMismatch |
| 冪等性・再試行 | 同buildの証跡に結び付け、別buildへ合格を流用しない |
| 対応REQ | [AC-02](../../req/features/app-icon-branding.md#ac-02), [AC-03](../../req/features/app-icon-branding.md#ac-03), [AC-04](../../req/features/app-icon-branding.md#ac-04) |

## SPEC-01: アセットと表示

マスターは`assets/icon/app_icon_master.png`、色調は`AppTheme`のインディゴを参照する。新しい絵柄は作らず、既存マスターの財布・支出管理のモチーフを維持して必要サイズへ出力する。四隅へ重要な図形・文字を置かず、OSのマスク後にモチーフが欠けないことを確認する。

iOSは`ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`のfilename/size/scaleを正とし、各filenameに指定されたピクセル数のPNGを配置する。配布用画像は不透明にする。Androidは`android/app/src/main/AndroidManifest.xml`のicon参照と既存mipmapリソースを正とし、密度ごとのPNGを収録する。既存にないadaptive iconの新方式導入は今回の完了条件にしない。

## SPEC-02: 更新・検査

Build task → BrandAssetService → ManifestReader/ImageTransform/AssetValidator。業務Repository・ネットワーク同期・支出の値型に依存させない。

以下はPortのInfrastructure実装と計算/表示Policyの具体化。具象DB・通知SDKをDomainへ持ち込まない。複数の物理テーブルに分かれていても、上の集約境界と契約単位で保存する。

変更が必要なときは既存マスターから同じモチーフを比率保持で縮小し、プラットフォーム指定寸法へ書き出す。生成方法・実行コマンド・対象ファイルは実装時の証跡へ記録する。マスターと派生PNGはリポジトリに置く。必要な寸法が未生成の場合は既定Flutterロゴで代用せず未完了として扱う。

## SPEC-03: 異常系・理由

ビルド設定が参照する画像欠落、寸法不一致、iOS配布画像の透過は検査エラーとする。小さいサイズでのモチーフ判別は代表実機のホーム画面で手動確認する。既存マスターを正本とすることでOS間で異なる絵柄になることを避ける。

## REQ対応・検証入口

- [app-icon-branding/AC-01](../../req/features/app-icon-branding.md#ac-01): 本書のSPEC-01〜03で具体化。
- [app-icon-branding/AC-02](../../req/features/app-icon-branding.md#ac-02): 本書のSPEC-01〜03で具体化。
- [app-icon-branding/AC-03](../../req/features/app-icon-branding.md#ac-03): 本書のSPEC-01〜03で具体化。
- [app-icon-branding/AC-04](../../req/features/app-icon-branding.md#ac-04): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。

## 契約検証・実装への移行

[機能別検証計画](../../verification/features/app-icon-branding.md)のTC-CTで公開契約ごとの前提違反・成功保証・不変条件・失敗時副作用・再試行を検証する。既存SPEC-01〜03の業務/画面条件を契約の詳細規則として維持する。既存実装と途中の変更は移行元であり、本設計に適合済みとは扱わない。
