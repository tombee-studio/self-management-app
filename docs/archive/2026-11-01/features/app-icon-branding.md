# アプリアイコン・ブランディング 設計（既存資料の統合）

- **バージョン**: v0.1.0
- **ステータス**: draft
- **資料区分**: 過去資料（現行仕様・工程ゲートの対象外）
- **整理日**: 2026-11-01（JST）

対応要求: [要求案](../../../req/features/app-icon-branding.md)。要求がdraftのため、本書は未確定の既存設計資料として保管する。

## 保存時点の移行範囲と確定条件

既存の仕様・詳細設計を同一文書へ移した。以下の保存節は当時の案であり、実装との一致・検証完了を保証しない。重複や矛盾は採用判断をせず保持し、[差分一覧](../../../STATUS.md)へ記録した。REQ確定後に振る舞い・データモデル・状態管理・異常系を同期し、レビューする。

## 保存資料: app-icon-branding / 仕様

移行元: `docs/spec/features/app-icon-branding.md`。旧節番号とコード例を保持。

### 支出管理アプリアイコン＆ブランディング (app-icon-branding) 仕様書

#### 1. 目的・概要
本仕様は、本アプリケーション「iris 支出管理」のホーム画面アプリアイコンを、デフォルトのFlutterアイコンから **「支出管理・家計簿アプリであることが一目で直感的にわかる」** 洗練されたモダンアイコンへ刷新するための要件を定義する。

##### 1.1 背景と課題
- 現在のアプリアイコンは初期設定のFlutterロゴのままであり、端末のホーム画面上で「支出管理アプリ」であることが認識できない。
- 実機（iPhone/iPad/Android）で日常的に利用する際、探しやすい視認性と、アプリ全体のデザインシステム（[AppTheme](../../../../lib/core/theme/app_theme.dart) - インディゴ基調の上品なトーン）に合致した世界観の確立が必要である。

---

#### 2. アイコンデザイン要件

##### 2.1 コンセプト・モチーフ
- **デザインコンセプト**: 「シンプル・モダン・スマートな支出管理」
- **主要モチーフ**:
  1. **スマートウォレット（財布）/ マネーカード**: 支出・決済・お金の管理を直感的に象徴。
  2. **通貨シンボル / コイン (¥)**: 日本円（JPY）での日々の支出記録を明確に示す。
  3. **成長・分析を示すチャートライン**: 予算管理・節約の達成感を表現。
  4. **irisカラーパレット**: アプリのプライマリカラー（Indigo `#4F46E5` 〜 Violet `#7C3AED`）の滑らかなグラデーション背景。
- **スタイリング**:
  - 過度な立体感（スキューモーフィズム）を避け、フラット〜微細なグラデーションとソフトシャドウを用いたモダンなネオモルフィズム/クリーンデザイン。
  - 小さなサイズ（ホーム画面や通知バナー）でも中央のモチーフがはっきりと視認できる高いコントラスト。

##### 2.2 各プラットフォーム仕様要件

###### ① iOS (iPhone / iPad)
- **形式**: PNG (透過なし・角丸なしの正方形、アルファチャンネル不許可)
- **マスター解像度**: 1024 × 1024 px (App Store用)
- **対応サイズ群**:
  - iPhone: 20pt, 29pt, 40pt, 60pt (@2x, @3x)
  - iPad: 20pt, 29pt, 40pt, 76pt, 83.5pt (@1x, @2x)
  - Settings / Spotlight / Notification 用各解像度

###### ② Android
- **形式**: Adaptive Icon（Foreground + Background）または レガシーPNG
- **対応解像度**:
  - `mipmap-mdpi` (48x48)
  - `mipmap-hdpi` (72x72)
  - `mipmap-xhdpi` (96x96)
  - `mipmap-xxhdpi` (144x144)
  - `mipmap-xxxhdpi` (192x192)

---

#### 3. 画面および配置要件
- **配置先**:
  - iOS: [ios/Runner/Assets.xcassets/AppIcon.appiconset/](../../../../ios/Runner/Assets.xcassets/AppIcon.appiconset)
  - Android: `android/app/src/main/res/mipmap-*/`
  - アプリ内（設定画面や「irisについて」モーダル）でのアプリアイコン表示

---

#### 4. 制約・受け入れ基準
1. **視認性**: iPhoneのホーム画面（通常表示およびダークモード、フォルダ内）において、一目で支出管理アプリと判別できること。
2. **規格適合**: App Store審査ガイドラインおよびXcodeのAsset Catalog仕様（1024x1024px、不透明）を完全に満たすこと。
3. **ビルドエラーの防止**: 既存のXcodeビルド（Release/Profile/Debug）で警告・エラーが発生しないこと。

## 保存資料: app-icon-branding / 詳細設計

移行元: `docs/implementation/features/app-icon-branding.md`。旧節番号とコード例を保持。

### 支出管理アプリアイコン＆ブランディング (app-icon-branding) 詳細設計書

#### 1. 概要
- **対応仕様書**: [docs/spec/features/app-icon-branding.md](../../../spec/features/app-icon-branding.md)
- **目的**: 支出管理アプリ「iris」のブランドアイデンティティを確立し、iOSおよびAndroid端末のホーム画面で一目で家計簿・支出管理と識別できるアプリアイコンアセットセットを生成・配置・構成する。

---

#### 2. ビジュアルデザイン仕様

##### 2.1 カラーパレット
| 要素 | カラーコード | 役割 |
| :--- | :--- | :--- |
| 背景グラデーション (Start) | `#4F46E5` (Indigo 600) | アプリ基本テーマカラー |
| 背景グラデーション (End) | `#7C3AED` (Violet 600) | 深みとモダンなプレミアム感を演出 |
| ウォレット（財布）本体 | `#FFFFFF` (White) / `#F8FAFC` (Slate 50) | 清潔感・コントラストを強調 |
| コイン / 通貨マーク (¥) | `#F59E0B` (Amber 500) 〜 `#FCD34D` | 金運・お金のシンボル |
| チャートアクセント | `#10B981` (Emerald 500) | 支出コントロール・健全な財務 |

##### 2.2 構図とシンボル配置
- **マスター画像仕様**: 1024 × 1024 px, 72 DPI, RGB (アルファ透過なし)
- **セーフエリア (Safe Zone)**:
  - 中央 800 × 800 px 内に主要シンボル（ウォレット＋円マークコイン）を配置。
  - 外周 112 px は各OSによる角丸マスク（iOS角丸クリッピング、Android円形マスク）で切り取られる領域としてマージンを確保。
- **シンボル造形**:
  - 開いた、またはスマートに閉じたミニマルウォレット（カードスロットが見える形状）。
  - ウォレットからわずかに飛び出すゴールドのコイン（¥マーク刻印）。

---

#### 3. アセット生成・リサイズパイプライン

##### 3.1 採用方針
アセット生成は以下の2段階で実施する：
1. **マスター画像の作成**:
   - 1024×1024pxの高解像度PNG画像（`assets/icon/app_icon_master.png`）を生成。
2. **各OS用アセットへのリサイズ・配置**:
   - `flutter_launcher_icons` パッケージの利用、またはImageMagick / Python / Dartスクリプトによるリサイズで各プラットフォーム規格のディレクトリへ一括配置。

##### 3.2 プラットフォーム別配置マッピング

###### iOS (`ios/Runner/Assets.xcassets/AppIcon.appiconset/`)
`Contents.json` に定義される以下のサイズセットを生成・上書き：
- `Icon-App-20x20@2x.png` (40×40)
- `Icon-App-20x20@3x.png` (60×60)
- `Icon-App-29x29@1x.png` (29×29)
- `Icon-App-29x29@2x.png` (58×58)
- `Icon-App-29x29@3x.png` (87×87)
- `Icon-App-40x40@2x.png` (80×80)
- `Icon-App-40x40@3x.png` (120×120)
- `Icon-App-60x60@2x.png` (120×120)
- `Icon-App-60x60@3x.png` (180×180)
- `Icon-App-76x76@1x.png` (76×76)
- `Icon-App-76x76@2x.png` (152×152)
- `Icon-App-83.5x83.5@2x.png` (167×167)
- `Icon-App-1024x1024@1x.png` (1024×1024)

###### Android (`android/app/src/main/res/`)
- `mipmap-mdpi/ic_launcher.png` (48×48)
- `mipmap-hdpi/ic_launcher.png` (72×72)
- `mipmap-xhdpi/ic_launcher.png` (96×96)
- `mipmap-xxhdpi/ic_launcher.png` (144×144)
- `mipmap-xxxhdpi/ic_launcher.png` (192×192)

---

#### 4. 検証・品質保証項目
1. **Xcode アセット検証**:
   - Xcode で `Assets.xcassets` を開いた際、AppIcon に警告（Missing Sizes や Transparency Warning）が出ないこと。
2. **実機表示確認**:
   - iOS シミュレータおよび実機にインストールし、ホーム画面で新アイコンが鮮明に表示されること。
3. **アスペクト比とクリッピング**:
   - iOSの角丸スーパー楕円（Squircle）クリッピングにより、中央のウォレット/コインの視認性が損なわれないこと。
