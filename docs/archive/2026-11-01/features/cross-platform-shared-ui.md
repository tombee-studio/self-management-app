# 共通UI・マルチデバイス対応 設計（既存資料の統合）

- **バージョン**: v0.1.0
- **ステータス**: draft
- **資料区分**: 過去資料（現行仕様・工程ゲートの対象外）
- **整理日**: 2026-11-01（JST）

対応要求: [要求案](../../../req/features/cross-platform-shared-ui.md)。要求がdraftのため、本書は未確定の既存設計資料として保管する。

## 保存時点の移行範囲と確定条件

既存の仕様・詳細設計を同一文書へ移した。以下の保存節は当時の案であり、実装との一致・検証完了を保証しない。重複や矛盾は採用判断をせず保持し、[差分一覧](../../../STATUS.md)へ記録した。REQ確定後に振る舞い・データモデル・状態管理・異常系を同期し、レビューする。

追加項目は親機能へ集約: `multi-device-responsive-layout`。同じ対象データ・操作の拡張であり、独立した機能として重複登録しない。

## 保存資料: cross-platform-shared-ui / 仕様

移行元: `docs/spec/features/cross-platform-shared-ui.md`。旧節番号とコード例を保持。

### クロスプラットフォームUI共通化 (cross-platform-shared-ui) 仕様書

#### 1. 目的・概要
本プロジェクトでは、クロスプラットフォームフレームワークとして **Flutter (Dart)** を全面採用し、iOS（iPhone / iPad）および Android 端末間における UI およびビジネスロジックのソースコード共通化率を最大化（95%以上）する。
これにより、OSごとに別々のUI（SwiftUI / Jetpack Compose等）を開発・保守するコストを完全に排除し、全デバイスで一貫した洗練されたデザインと快適な操作感を提供する。

---

#### 2. フレームワーク選定と共通化方針

##### 2.1 採用技術
- **フレームワーク**: **Flutter** (最新安定版 3.x+)
- **開発言語**: **Dart** (Null-safety 完全対応)
- **レンダリングエンジン**: **Impeller**（iOS / Androidで安定した 60/120fps 滑らか描画）

##### 2.2 ソースコード共通化の範囲

```text
┌─────────────────────────────────────────────────────────────┐
│ 【100% 共通化】 UI・プレゼンテーション層 (Flutter Widgets)    │
│  ・全画面 (Screens)                                         │
│  ・コンポーネント (Widgets / Components)                    │
│  ・テーマ・デザインシステム (ThemeData / Design Tokens)       │
│  ・レスポンシブ・アダプティブ分岐 (LayoutBuilder)            │
├─────────────────────────────────────────────────────────────┤
│ 【100% 共通化】 ドメイン＆データ層 (Pure Dart)              │
│  ・状態管理 (State Management)                              │
│  ・集計ロジック・計算処理・バリデーション                   │
│  ・データモデル (Models / Freezed 等)                       │
│  ・ローカルDB (SQLite / drift / hive 等)                    │
├─────────────────────────────────────────────────────────────┤
│ 【共通インターフェース化】 ネイティブ抽象化層 (MethodChannel) │
│  ・PaymentEventPlatformInterface (決済イベント受信)         │
│  ・NotificationPlatformInterface (通知)                     │
└──────────────────────────┬──────────────────────────────────┘
                           ▼ (OS固有の最小限ネイティブ実装のみ分離)
              ┌────────────┴────────────┐
              ▼                         ▼
      [iOS ネイティブ層]           [Android ネイティブ層]
      ・App Intents / Shortcuts   ・BroadcastReceiver / Wallet
```

---

#### 3. UI共通化における設計要件

##### 3.1 独自デザインシステムの一元化
- OS標準のUIに引きずられず、本アプリ独自のモダンで洗練されたデザインシステムを Flutter の `ThemeData` として構築。
- カラーパレット、フォントスタイル、カードのシャドウ・角丸、アニメーション遷移を全プラットフォームで統一。

##### 3.2 アダプティブ（画面サイズ適応）の共通実装
- プラットフォーム名（iOS/Android）による分岐ではなく、画面幅（`MediaQuery` / `LayoutBuilder`）に基づいたサイズクラス（Compact / Medium / Expanded）による共通レスポンシブウィジェットを使用。
- スマホ横向き、タブレット2ペイン（Master-Detail）のすべてのレイアウトが単一の Flutter ウィジェットツリー内で完結。

##### 3.3 プラットフォーム固有機能の分離（プラグイン設計）
- Apple Pay（iOS Shortcuts / App Intents）や通知等のネイティブ機能は、UIレイヤから直接呼ばず、抽象化されたインターフェース（Platform Interface）経由で通信。
- UIコード内には `Platform.isIOS` のようなプラットフォーム判定を極力含めず、純粋なUIロジックとして完結させる。

---

#### 4. 期待効果と非機能要件
1. **開発・保守工数の半減**: 1つのソースコードベースですべての修正・機能追加が全プラットフォームに即時反映。
2. **デザインの再現性**: Flutter の独自キャンバス描画により、OSや端末ごとの表示差異（フォントのズレ、パディング崩れ）を完全に防止。
3. **テスタビリティ**: Flutter Widget テストを活用し、実機を使わずCI上で全プラットフォームのUI描画・操作テストを高速実行可能。

## 保存資料: cross-platform-shared-ui / 詳細設計

移行元: `docs/implementation/features/cross-platform-shared-ui.md`。旧節番号とコード例を保持。

### クロスプラットフォームUI共通化 (cross-platform-shared-ui) 詳細設計書

#### 1. 概要
- **対応仕様書**: [docs/spec/features/cross-platform-shared-ui.md](../../../spec/features/cross-platform-shared-ui.md)
- **採用技術**: **Flutter (Dart)**
- **目的**: Flutter の宣言的UIとコンポーネント指向を活用し、全画面・全コンポーネントを 100% 共通の Dart コードで実装するためのアーキテクチャ設計を定義する。

---

#### 2. ディレクトリ構成とレイヤードアーキテクチャ

Flutter 標準のフィーチャー指向（Feature-first）かつレイヤード設計を採用する。

```text
lib/
├── app/                      # アプリ全体の設定・エントリポイント
│   ├── app.dart              # MaterialApp.router
│   ├── routes.dart           # ルーティング設定 (go_router)
│   └── theme/                # 共通デザインシステム
│       ├── colors.dart       # カラーパレット (AppColors)
│       ├── typography.dart   # タイポグラフィ (AppTypography)
│       └── app_theme.dart    # ThemeData 定義
├── core/                     # アプリ全体で共有するユーティリティ・基盤
│   ├── adaptive/             # レスポンシブ・ブレークポイント判定
│   │   ├── window_size.dart  # WindowWidthSizeClass / AdaptiveContext
│   │   └── adaptive_scaffold.dart # アダプティブScaffold
│   └── platform/             # ネイティブ連携インターフェース
│       └── payment_channel.dart # MethodChannel 抽象化
└── features/                 # 機能別モジュール
    ├── dashboard/            # 日次ダッシュボード機能
    │   ├── presentation/     # UI (Widgets, Screens, Notifiers)
    │   ├── domain/           # ビジネスロジック・エンティティ
    │   └── data/             # リポジトリ・データソース
    └── payment_integration/  # 外部決済イベント連携機能
        ├── presentation/
        ├── domain/
        └── data/
```

---

#### 3. デザインシステム設計 (`ThemeData`)

OS標準スタイルに依存せず、アプリ独自のデザインシステムを定義して全画面に適用する。

```dart
// lib/app/theme/colors.dart
class AppColors {
  static const primary = Color(0xFF4F46E5);      // Indigo 600
  static const primaryLight = Color(0xFFEEF2FF); // Indigo 50
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8FAFC);       // Slate 50
  static const border = Color(0xFFE2E8F0);        // Slate 200
  static const textPrimary = Color(0xFF0F172A);   // Slate 900
  static const textSecondary = Color(0xFF64748B); // Slate 500
  static const success = Color(0xFF10B981);       // Emerald 500
  static const danger = Color(0xFFEF4444);        // Red 500
}

// lib/app/theme/app_theme.dart
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      background: AppColors.background,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}
```

---

#### 4. アダプティブScaffoldの共通設計 (`AdaptiveScaffold`)

デバイスの横幅に応じて、ボトムナビ、ナビゲーションレール、パーマネントサイドバーを同一ウィジェットツリー内でシームレスに切り替える。

```dart
// lib/core/adaptive/adaptive_scaffold.dart
class AdaptiveScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget body;

  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Expanded: タブレット横向き (840px 〜)
        if (width >= 840) {
          return Scaffold(
            body: Row(
              children: [
                PermanentDrawer(
                  selectedIndex: selectedIndex,
                  onSelected: onDestinationSelected,
                  destinations: destinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        // Medium: スマホ横向き・タブレット縦向き (600px 〜 839px)
        if (width >= 600) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations.map((d) => NavigationRailDestination(
                    icon: d.icon,
                    label: Text(d.label),
                  )).toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        // Compact: スマホ縦向き (〜 599px)
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
```

---

#### 5. ネイティブ連携（MethodChannel）の局所化

UI層にプラットフォーム依存コードを持ち込ませないため、`MethodChannel` をサービス層に隠蔽する。

```dart
// lib/core/platform/payment_channel.dart
abstract class PaymentPlatformBridge {
  Stream<Map<String, dynamic>> get onPaymentEventReceived;
}

class MethodChannelPaymentBridge implements PaymentPlatformBridge {
  static const _channel = EventChannel('com.iris.app/payment_events');

  @override
  Stream<Map<String, dynamic>> get onPaymentEventReceived {
    return _channel.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event));
  }
}
```

---

#### 6. テスト戦略

1. **ウィジェットテスト (Widget Test)**:
   - `WidgetTester` を使用し、Compact、Medium、Expanded の各画面幅でテストを実行（`tester.binding.setSurfaceSize(Size(width, height))`）。
   - ナビゲーションの切り替えや 2ペインの展開を実機不要で自動検証。
2. **ロジック単体テスト (Unit Test)**:
   - 集計ロジックやアダプタ正規化処理を純粋な Dart Unit Test で検証。

## 保存資料: multi-device-responsive-layout / 仕様

移行元: `docs/spec/features/multi-device-responsive-layout.md`。旧節番号とコード例を保持。

### マルチデバイス＆画面回転アダプティブ対応 (multi-device-responsive-layout) 仕様書

#### 1. 目的・概要
本アプリケーションは、スマートフォンおよびタブレットの双方において、縦向き（Portrait）および横向き（Landscape）のいずれの画面の向きでも快適かつ直感的に操作できるレスポンシブ・アダプティブUIを提供する。
対象OSは iOS を第1弾とし、将来的な Android への拡張を前提としたマルチプラットフォーム設計とする。

---

#### 2. プラットフォーム・デバイス要件

##### 2.1 対象プラットフォーム
- **Primary (Phase 1)**: iOS 16.0 以降（iPhone、iPad）
- **Secondary (Phase 2 拡張予定)**: Android 12.0 以降（スマートフォン、タブレット、折りたたみ端末）

##### 2.2 対象デバイスおよび画面の向き
- **スマートフォン**:
  - 縦向き (Portrait): 標準操作（片手操作・親指リーチ重視）
  - 横向き (Landscape): ワイド表示対応（グラフや明細の俯瞰）
- **タブレット (iPad / Android Tablet)**:
  - 縦向き (Portrait): 大画面1カラムまたは上部2カラム配置
  - 横向き (Landscape): **2ペイン（マスター・ディテール）分割ビュー**
  - 可変ウィンドウ（iPadOS Stage Manager / Split View / Slide Over）対応

---

#### 3. レスポンシブブレークポイント仕様

Material 3 / HIG のアダプティブデザイン指針に準拠し、以下の3つのウィンドウサイズクラスを定義する。

| クラス名 | 幅（Width）範囲 | 主な対象画面 | 基本レイアウト構成 | ナビゲーション方式 |
| :--- | :--- | :--- | :--- | :--- |
| **Compact** | 〜 599px | スマホ縦向き | 1カラム縦スクロール<br>（ヘッダー ➔ サマリー ➔ 内訳 ➔ 明細） | **ボトムナビゲーションバー**<br>（画面下部固定） |
| **Medium** | 600px 〜 839px | スマホ横向き<br>小型タブレット縦向き<br>iPad Split View (1/2) | 最適化グリッド<br>（サマリーと内訳を横並び ➔ 下部に明細） | **ナビゲーションレール**<br>（画面左端にアイコン縦並び） |
| **Expanded** | 840px 〜 | タブレット横向き<br>大型タブレット（iPad Pro等） | **2ペイン（スプリットビュー）**<br>・左ペイン: 日付選択・サマリー・内訳<br>・右ペイン: 支出明細・インライン編集 | **サイドナビゲーションバー**<br>（画面左端にアイコン＋ラベル常時固定） |

---

#### 4. 画面・コンポーネント詳細仕様

##### 4.1 スマホ横向き (Compact / Medium Landscape)
- **課題**: 垂直方向の高さ（高さ350px〜450px程度）が制限される。
- **対応仕様**:
  - ヘッダー（日付セレクタ）およびサマリーカードの高さをコンパクト化。
  - ボトムナビゲーションを非表示化し、左端の**ナビゲーションレール**に切り替えて上下の作業領域を最大化。
  - 支出入力モーダルはフルスクリーンではなく、画面右半分にスライドインするシート形式を採用。

##### 4.2 タブレット横向き (Expanded 2-Pane Layout)
- **左ペイン (幅 380px 固定または 40%)**:
  - 日付セレクタ（月間カレンダーピッカー埋め込み）
  - 当日合計サマリーカード
  - カテゴリ別支出比率チャート
- **右ペイン (可変幅 / 残り領域)**:
  - 選択日の支出明細一覧（複数列グリッドまたは詳細テーブル）
  - 明細タップ時はモーダルではなく右ペイン内でインライン詳細・編集パネルを展開
  - クイック追加ボタン（右ペイン上部または右下固定）

##### 4.3 画面構成および画面仕様 (draw.io)
- **ファイル**: [docs/spec/screens.drawio](../../../spec/screens.drawio)
  - タブ: `マルチデバイス・画面回転レイアウト`
  - スマホ横向き、およびタブレット横向き（2ペイン）のレイアウトと画面仕様一覧を定義。

---

#### 5. OS・ハードウェア統合要件

##### 5.1 セーフエリア (SafeArea) & カットアウト
- ノッチ（iPhone X〜14）、Dynamic Island（iPhone 14 Pro〜）、ホームインジケータバー、およびパンチホールカメラの周囲に適切なパディングを動的確保する。
- 横向き時は、左右のセーフエリア（特にノッチ側）を考慮し、コンテンツが欠けないよう余白を調整。

##### 5.2 iPadOS 固有の機能対応
- **ウィンドウリサイズ**: Stage Manager や Split View の境界ドラッグによる幅・高さ変更時、画面を再ロードせずリアルタイムにレイアウトクラスを切り替える。
- **ハードウェアキーボードショートカット**:
  - `⌘ + N`: 新規支出追加
  - `⌘ + ←` / `⌘ + →`: 前日 / 翌日への切り替え
  - `Esc`: モーダル / シートを閉じる

---

#### 6. エラーハンドリング・エッジケース

- **極小画面（幅320px未満、Split View極小時）**:
  - コンテンツが最小幅を割り込まないよう水平スクロールを許容するか、最小フォントサイズを適用してオーバーフロー（はみ出し）を防止。
- **画面回転中アニメーション**:
  - 画面回転時にレイアウトシフトのちらつきが発生しないよう、Fluid Animation（なめらかな再配置トランジション）を適用。

## 保存資料: multi-device-responsive-layout / 詳細設計

移行元: `docs/implementation/features/multi-device-responsive-layout.md`。旧節番号とコード例を保持。

### マルチデバイス＆画面回転アダプティブ対応 (multi-device-responsive-layout) 詳細設計書

#### 1. 概要
- **対応仕様書**: [docs/spec/features/multi-device-responsive-layout.md](../../../spec/features/cross-platform-shared-ui.md)
- **目的**: iOS/Androidのスマートフォン・タブレット、および縦型・横型の画面向きに対応するレスポンシブ・アダプティブなUIアーキテクチャを設計する。

---

#### 2. レスポンシブアーキテクチャ設計

##### 2.1 ウィンドウサイズクラス定義

```typescript
export enum WindowWidthSizeClass {
  Compact = 'compact',   // 0 <= width < 600
  Medium = 'medium',     // 600 <= width < 840
  Expanded = 'expanded', // 840 <= width
}

export enum DeviceOrientation {
  Portrait = 'portrait',
  Landscape = 'landscape',
}

export interface AdaptiveWindowContext {
  widthClass: WindowWidthSizeClass;
  orientation: DeviceOrientation;
  screenWidth: number;
  screenHeight: number;
  isTabletOrDesktop: boolean;
  safeAreaInsets: { top: number; bottom: number; left: number; right: number };
}
```

##### 2.2 ウィンドウ判定ロジック (`resolveWindowContext`)

```typescript
export function resolveWindowContext(
  width: number,
  height: number,
  safeAreaInsets: { top: number; bottom: number; left: number; right: number }
): AdaptiveWindowContext {
  let widthClass = WindowWidthSizeClass.Compact;
  if (width >= 840) {
    widthClass = WindowWidthSizeClass.Expanded;
  } else if (width >= 600) {
    widthClass = WindowWidthSizeClass.Medium;
  }

  const orientation = width > height ? DeviceOrientation.Landscape : DeviceOrientation.Portrait;
  const isTabletOrDesktop = width >= 600;

  return {
    widthClass,
    orientation,
    screenWidth: width,
    screenHeight: height,
    isTabletOrDesktop,
    safeAreaInsets,
  };
}
```

---

#### 3. アダプティブナビゲーション設計 (`AdaptiveNavigationScaffold`)

画面サイズクラスに応じて、適切なナビゲーションコンポーネントを動的に切り替える。

```text
[AdaptiveNavigationScaffold]
  ├── Compact (スマホ縦):
  │     └── [Scaffold Body] + [BottomNavigationBar]
  ├── Medium (スマホ横 / タブレット縦):
  │     └── [NavigationRail (左端)] + [Scaffold Body]
  └── Expanded (タブレット横 / 大画面):
        └── [PermanentSidebar (左側固定)] + [Scaffold Body]
```

##### 3.1 コンポーネント構造
- `NavigationRail`: アイコンのみの縦並びスリムバー（幅 72px）。横向き時の縦領域を圧迫しない。
- `PermanentSidebar`: アイコン＋テキストラベル、およびアプリロゴを表示するフル機能サイドバー（幅 240px）。

---

#### 4. ダッシュボード 2ペイン設計 (`AdaptiveDashboardView`)

サイズクラスが `Expanded`（タブレット横等）の場合、ダッシュボード画面を 2ペイン分割構成に自動展開する。

```text
+---------------------+---------------------------------------------------------+
| PermanentSidebar    | AdaptiveDashboardView (Expanded 2-Pane)                 |
| (240px)             |                                                         |
|                     | +-----------------------+-----------------------------+ |
| [Logo]              | | MasterPane (400px)    | DetailPane (Flexible)       | |
|                     | |                       |                             | |
| 🏠 ホーム           | | ・月間カレンダー/セレクタ | ・当日の支出明細テーブル    | |
| 📅 カレンダー       | | ・日次サマリーカード   | ・明細インライン編集パネル   | |
| 📊 レポート         | | ・カテゴリ別円グラフ   | ・支出クイック登録フォーム  | |
| ⚙️ 設定             | |                       |                             | |
|                     | +-----------------------+-----------------------------+ |
+---------------------+---------------------------------------------------------+
```

##### 4.1 ペイン間連携の状態管理 (`DashboardSelectionState`)
- `selectedDate`: カレンダー/セレクタで選択された日付（マスター側で更新 ➔ ディテール側で即時該当明細を表示）。
- `selectedExpenseId`: 選択中の支出明細ID（右ペイン内でインライン詳細・編集パネルを展開）。

---

#### 5. キーボードショートカット＆セーフエリア制御

##### 5.1 キーボードイベントリスナー (`ShortcutManager`)
タブレット（外付けキーボード）接続時に以下のキーイベントを捕捉する。

```typescript
export const KeyboardShortcuts = {
  NEW_EXPENSE: { key: 'n', meta: true },       // ⌘ + N
  PREV_DAY: { key: 'ArrowLeft', meta: true },   // ⌘ + ←
  NEXT_DAY: { key: 'ArrowRight', meta: true },  // ⌘ + →
  CLOSE_MODAL: { key: 'Escape' },               // Esc
};
```

##### 5.2 セーフエリアパディング処理
横向き（Landscape）時は、端末の向きによって左または右にノッチ/Dynamic Islandが存在するため、`SafeArea` を適用して内部コンテナの `paddingLeft` / `paddingRight` を動的に注入する。

---

#### 6. テスト設計

##### 6.1 ロジック単体テスト
- `resolveWindowContext`:
  - 375x812 (iPhone 縦) ➔ `Compact`, `Portrait`
  - 812x375 (iPhone 横) ➔ `Medium` (または `Compact` 閾値), `Landscape`
  - 1024x768 (iPad 縦/横) ➔ `Expanded`, `Landscape`
  - 境界値（599px, 600px, 839px, 840px）でのクラス判定。

##### 6.2 レイアウトテスト（ゴールデンテスト / ウィジェットテスト）
- Compact（幅 375px）でボトムナビが表示され、サマリーが縦積みされること。
- Medium（幅 700px）でナビゲーションレールが表示されること。
- Expanded（幅 1024px）で2ペイン（マスター・ディテール）が正しく左右分割配置されること。
