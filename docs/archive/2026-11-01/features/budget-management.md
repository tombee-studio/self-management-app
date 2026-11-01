# 予算設定・管理 設計（既存資料の統合）

- **バージョン**: v0.1.0
- **ステータス**: draft
- **資料区分**: 過去資料（現行仕様・工程ゲートの対象外）
- **整理日**: 2026-11-01（JST）

対応要求: [要求案](../../../req/features/budget-management.md)。要求がdraftのため、本書は未確定の既存設計資料として保管する。

## 保存時点の移行範囲と確定条件

既存の仕様・詳細設計を同一文書へ移した。以下の保存節は当時の案であり、実装との一致・検証完了を保証しない。重複や矛盾は採用判断をせず保持し、[差分一覧](../../../STATUS.md)へ記録した。REQ確定後に振る舞い・データモデル・状態管理・異常系を同期し、レビューする。

追加項目は親機能へ集約: `budget-settings-navigation-ux`。同じ対象データ・操作の拡張であり、独立した機能として重複登録しない。

## 保存資料: budget-management / 仕様

移行元: `docs/spec/features/budget-management.md`。旧節番号とコード例を保持。

### 予算設定・管理機能 (budget-management) 仕様書

#### 1. 目的・概要
ユーザーが月間目標予算およびカテゴリ別予算を設定し、日々の支出ペースや消化状況を直感的に把握できるようにする。
月の残り日数に応じた「1日あたりの使える金額」の自動計算や、使いすぎ予測アラートにより、計画的な支出管理と節約意識の維持を支援する。

---

#### 2. ユーザーフロー・画面要件

##### 2.1 ユーザーフロー
1. **予算設定への導線**:
   - 日次支出ダッシュボードのサマリーカード内「予算プログレスバー」タップ、または設定メニューから「予算設定画面」を開く。
2. **月間予算の設定**:
   - 月間の目標総支出額（例: `¥180,000`）を入力する。
   - 家計のサイクルに合わせて「予算開始日」（デフォルト: 毎月1日、または給料日等の25日など）を選択する。
3. **カテゴリ別配分設定（オプション）**:
   - 「カテゴリ別予算」を有効化すると、食費・日用品・交際費・固定費などのカテゴリごとに予算枠を配分できる。
   - カテゴリ合計と月間総予算の差額（未配分額）がリアルタイムに表示される。
4. **消化状況の確認**:
   - **月間プログレス**: 当月の総支出額、予算消化率（%）、残予算。
   - **日次推奨予算（動的配分）**: 「今月残り日数」と「残予算」から算出した「本日使える目安額」を確認。
   - **ペース予測診断**: 「このペースで使うと月末には ¥210,000（3万円超過）になる見込みです」などのアラートカードを表示。

##### 2.2 画面コンポーネント要件
- **画面構成および画面仕様 (draw.io)**: [docs/spec/screens.drawio](../../../spec/screens.drawio) （タブ: `予算設定・管理画面` / SCR-006）
- **キーボード＆画面遷移UX仕様**: [docs/spec/features/budget-settings-navigation-ux.md](../../../spec/features/budget-management.md) を参照
- **ヘッダー**: 画面タイトル「予算設定・管理」、戻るボタン（今日タブへ復帰 / 画面Pop）、保存ボタン（キーボード解除・DB保存・今日タブへ自動復帰）
- **月間総予算カード**:
  - 現在の月間総予算入力（テンキー入力、完了Doneアクションまたは背景タップでキーボード解除）
  - 予算サイクルの開始日セレクタ（毎月1日〜28日）
- **当月進捗・ペース診断カード**:
  - 全体プログレスバー（緑: 安全 < 70%, 黄: 注意 70-99%, 赤: 超過 ≥ 100%）
  - 本日の推奨支出上限（今日使える金額）
  - 月末着地予測支出額（現在のペースから日割り予測）
- **カテゴリ別予算配分リスト**:
  - 各カテゴリのアイコン、カテゴリ名、予算入力フィールド、現在の当月実績
  - 未配分残額インジケーター（総予算との整合チェック）
- **通知設定**:
  - 予算80%到達通知、100%超過通知のトグルスイッチ

---

#### 3. 入力項目・バリデーション

| 項目名 | 必須 | 形式 / 制約 | 初期値 | エラー条件・挙動 |
| :--- | :---: | :--- | :--- | :--- |
| **月間総予算** | ○ | 整数（JPY）<br>範囲: `1` 〜 `99,999,999` 円 | `150,000` | 0円または未入力時は保存不可。上限超過時は入力抑止。 |
| **予算開始日** | ○ | 整数（`1` 〜 `28` 日） | `1` (毎月1日) | 29日以降は月末日数の変動（2月等）を防ぐため選択不可。 |
| **カテゴリ別予算** | 任意 | 各カテゴリ: `0` 〜 `99,999,999` 円 | `0` | 個別カテゴリ予算の合計が月間総予算を超える場合、警告メッセージを表示（保存は許可）。 |
| **通知トグル** | ○ | Boolean（ON / OFF） | ON | - |

---

#### 4. ビジネスロジック・計算ルール

##### 4.1 予算期間の算出ロジック
- 設定された開始日（$StartDay$）に基づいて、当月の予算期間 $[PeriodStart, PeriodEnd]$ を決定する。
  - 例: 開始日が 25日の場合、10月25日 〜 11月24日 が当月予算期間となる。
- 当月の総日数: $Days_{total} = PeriodEnd - PeriodStart + 1$
- 経過日数: $Days_{passed} = CurrentDate - PeriodStart + 1$
- 残り日数: $Days_{remaining} = PeriodEnd - CurrentDate + 1$ （当日を含む）

##### 4.2 動的日次推奨予算 ($DailyRecommended$) の計算
「月全体で均等に使う場合」ではなく、**過去の使いすぎ・節約を吸収して本日いくら使えるか**を動的に算出する:
$$DailyRecommended = \max\left(0, \left\lfloor \frac{Budget_{month} - TotalSpentToDate}{Days_{remaining}} \right\rfloor\right)$$
- $TotalSpentToDate \ge Budget_{month}$ の場合、$DailyRecommended = 0$ 円となり、「今月は予算を使い切りました」と表示。

##### 4.3 月末着地予測 ($ProjectedExpense$) の計算
当月の平均日次支出ペースを月末まで維持した場合の予測総額:
$$ProjectedExpense = \left\lfloor \frac{TotalSpentToDate}{Days_{passed}} \times Days_{total} \right\rfloor$$
- $ProjectedExpense > Budget_{month}$ の場合、「このペースだと月末に約 ¥X 超過する見込みです」と警告バナーを表示。

---

#### 5. エラーハンドリング・エッジケース

1. **予算開始日の切り替わり直後**:
   - 期間初日（$Days_{passed} = 1$）において、実績が極端に高い・低い場合、ペース予測値が過剰に跳ね上がるのを防ぐため、開始後3日間はペース予測バナーを表示せず「データ収集中」とする。
2. **完全ローカル環境での通知**:
   - 外部プッシュ通知サーバーを使わず、支出登録・決済連携イベント直後にローカル通知（Flutter Local Notifications）を発行し、オフラインでも80%・100%超過通知を端末内完結で確実に届ける。

## 保存資料: budget-management / 詳細設計

移行元: `docs/implementation/features/budget-management.md`。旧節番号とコード例を保持。

### 予算設定・管理機能 (budget-management) 詳細設計書

#### 1. 概要・アーキテクチャ構成
本機能は、月間総予算およびカテゴリ別予算の永続化、日次推奨予算の動的計算、月末着地予測、および完全ローカル通知による超過アラートを提供します。

---

#### 2. コンポーネント構成・UIツリー

```
lib/features/budget/
├── domain/
│   ├── models/
│   │   ├── budget_summary.dart         # 当月予算進捗・予測サマリーモデル
│   │   └── category_budget_item.dart   # カテゴリ別配分アイテム
│   └── services/
│       └── budget_calculation_service.dart # 動的日次配分・月末予測ロジック
├── data/
│   └── repositories/
│       └── budget_repository.dart      # drift DB 予算データアクセス
└── presentation/
    ├── controllers/
    │   └── budget_controller.dart      # 予算設定状態管理 (StateNotifier)
    ├── screens/
    │   └── budget_settings_screen.dart # 予算設定画面 (SCR-006)
    └── widgets/
        ├── monthly_budget_card.dart    # 月間総予算・サイクル設定カード
        ├── budget_pace_card.dart       # 進捗メーター＆今日使える目安額
        ├── category_budget_section.dart# カテゴリ別予算設定リスト
        └── budget_notification_tile.dart# ローカル通知スイッチ
```

---

#### 3. データモデル・テーブル定義 (drift)

##### 3.1 テーブル定義
```dart
// 月間総予算・基本設定テーブル (単一レコード保持)
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get monthlyAmount => integer().withDefault(const Constant(150000))(); // 月間総予算（円）
  IntColumn get startDay => integer().withDefault(const Constant(1))();          // 開始日 (1〜28)
  BoolColumn get isCategoryBudgetEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get isAlertNotificationEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// カテゴリ別予算テーブル
class CategoryBudgets extends Table {
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get allocatedAmount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {categoryId};
}
```

##### 3.2 予算進捗サマリーモデル (`BudgetSummary`)
```dart
@freezed
class BudgetSummary with _$BudgetSummary {
  const factory BudgetSummary({
    required int monthlyBudget,            // 月間総予算
    required int totalSpent,              // 当月支出実績合計
    required int remainingBudget,          // 残予算
    required double progressPercentage,    // 消化率 (0.0 〜 1.0+)
    required int daysTotal,               // 期間総日数
    required int daysPassed,              // 経過日数
    required int daysRemaining,           // 残り日数（当日含む）
    required int dailyRecommended,        // 今日使える目安額
    required int projectedTotalExpense,    // 月末着地予測支出額
    required bool isOverBudget,           // 既に100%超過しているか
    required bool isProjectedToOverspend, // 現在ペースで超過見込みか
  }) = _BudgetSummary;
}
```

---

#### 4. ロジック・計算サービス設計 (`BudgetCalculationService`)

```dart
class BudgetCalculationService {
  /// 現在日時と設定値から当月の予算集計サマリーを算出する
  static BudgetSummary calculate({
    required int monthlyBudget,
    required int startDay,
    required int totalSpent,
    required DateTime now,
  }) {
    final period = _resolveBudgetPeriod(now, startDay);
    final daysTotal = period.end.difference(period.start).inDays + 1;
    final daysPassed = now.difference(period.start).inDays + 1;
    final daysRemaining = period.end.difference(now).inDays + 1;

    final remainingBudget = monthlyBudget - totalSpent;
    final progress = monthlyBudget > 0 ? (totalSpent / monthlyBudget) : 0.0;

    // 動的日次推奨額: (残予算 / 残り日数) を0以上でクリップ
    final dailyRec = daysRemaining > 0 && remainingBudget > 0
        ? (remainingBudget / daysRemaining).floor()
        : 0;

    // 月末予測: (実績 / 経過日数) * 総日数
    final projected = daysPassed > 0
        ? ((totalSpent / daysPassed) * daysTotal).floor()
        : totalSpent;

    return BudgetSummary(
      monthlyBudget: monthlyBudget,
      totalSpent: totalSpent,
      remainingBudget: remainingBudget,
      progressPercentage: progress,
      daysTotal: daysTotal,
      daysPassed: daysPassed,
      daysRemaining: daysRemaining,
      dailyRecommended: dailyRec,
      projectedTotalExpense: projected,
      isOverBudget: totalSpent >= monthlyBudget,
      isProjectedToOverspend: projected > monthlyBudget && daysPassed >= 3,
    );
  }

  static DateTimeRange _resolveBudgetPeriod(DateTime now, int startDay) {
    // startDay に基づく当月サイクルの開始日・終了日を算出
    DateTime start;
    if (now.day >= startDay) {
      start = DateTime(now.year, now.month, startDay);
    } else {
      start = DateTime(now.year, now.month - 1, startDay);
    }
    final nextMonth = DateTime(start.year, start.month + 1, startDay);
    final end = nextMonth.subtract(const Duration(days: 1));
    return DateTimeRange(start: start, end: end);
  }
}
```

---

#### 5. 超過アラート・ローカル通知設計 (`BudgetNotificationService`)

- **発火タイミング**:
  - 支出の手動登録、または外部決済連携（Apple Pay）による支出保存完了の直後。
- **通知判定条件**:
  1. `isAlertNotificationEnabled == true`
  2. 支出保存前の進捗率 $< 80\%$ かつ 保存後の進捗率 $\ge 80\%$ $\rightarrow$ `「予算の80%（¥X）を消化しました。残り ¥Y です。」`
  3. 支出保存前の進捗率 $< 100\%$ かつ 保存後の進捗率 $\ge 100\%$ $\rightarrow$ `「⚠️ 月間予算（¥X）を超過しました！」`
- **実装ライブラリ**: `flutter_local_notifications`
  - 端末内完結（ネットワーク不要、完全オフライン動作）。

---

#### 6. テスト計画

1. **計算サービス単体テスト (`test/unit/budget_calculation_service_test.dart`)**:
   - 予算期間算出テスト（1日始まり、25日給料日始まり）
   - 日次推奨予算の動的配分テスト（残予算がゼロ・マイナス時のクリッピング）
   - 月末着地予測テスト（開始3日未満時の予測除外確認）
2. **通知判定単体テスト (`test/unit/budget_notification_service_test.dart`)**:
   - 79%から81%への増加で通知が発火すること
   - 既に超過している状態での追加支出で重複通知が抑止されること
3. **ウィジェットテスト (`test/widget/budget_settings_screen_test.dart`)**:
   - 月間予算入力から保存までのUI操作検証
   - プログレスバーの色変化（緑/黄/赤）の描画検証

---

#### 7. 画面遷移・キーボードUX詳細設計
- 予算設定画面の入力後キーボード解除、保存後の自動画面遷移、戻るナビゲーションの詳細設計については [docs/implementation/features/budget-settings-navigation-ux.md](../../../spec/features/budget-management.md) を参照。


## 保存資料: budget-settings-navigation-ux / 仕様

移行元: `docs/spec/features/budget-settings-navigation-ux.md`。旧節番号とコード例を保持。

### 予算設定画面 入力後画面遷移・キーボードUX仕様書 (budget-settings-navigation-ux)

#### 1. 目的・概要
ユーザーが「予算設定・管理画面」で予算金額やサイクルを入力・変更した後、スムーズにキーボードを閉じ、完了後にダッシュボード（今日）等の別画面へ迷わず遷移できるようにする。

##### 現状の課題
1. **キーボード解除不能**: iOSの数値入力テンキーにはデフォルトで「完了」ボタンがなく、画面余白をタップしてもフォーカスが解除されないため、キーボードが表示されたまま画面下部のナビゲーション（BottomNavigationBar）が隠れる・遮られる。
2. **保存後の画面遷移欠如**: 右上の「保存」ボタン押下時にスナックバーは表示されるものの、キーボードが閉じず、かつ元の画面（ダッシュボード）へ自動復帰しないため、ユーザーが入力後に取り残される。
3. **戻る導線の不足**: タブ画面として表示されている際に、明示的にダッシュボードへ戻るボタンが存在しない。

---

#### 2. ユーザーフロー・画面要件

##### 2.1 ユーザーフロー
1. **予算設定画面の表示**:
   - 下部タブ「予算」またはダッシュボードの予算サマリーから「予算設定・管理画面」を開く。
2. **金額入力とキーボード操作**:
   - 「今月の総予算」テキストフィールドをタップすると数値テンキーが開く。
   - **キーボードを閉じる方法**:
     - 画面内の任意の余白（カード外、背景）をタップする。
     - またはキーボードの「完了 (Done)」アクションを実行する。
     - または右上の「保存」ボタンをタップする。
3. **保存と画面遷移**:
   - 右上の「保存」ボタンをタップする。
   - 入力内容をローカルDBに保存し、「予算設定を保存しました」メッセージを表示する。
   - **自動画面遷移**:
     - モーダル/Push遷移で開かれていた場合: 前の画面に自動で戻る（`Navigator.pop`）。
     - タブ（BottomNavigationBar）として開かれていた場合: 自動的に「今日（ダッシュボード）」タブ（Index 0）へ切り替える。
4. **キャンセル・戻る**:
   - AppBar左側の「‹ 今日」または戻るボタンをタップすると、キーボードを閉じてダッシュボード（今日）タブへ戻る。

##### 2.2 画面コンポーネント要件
- **画面仕様書 (draw.io)**: [docs/spec/screens.drawio](../../../spec/screens.drawio) （タブ: `予算設定・管理画面` / SCR-006）
- **AppBar (ヘッダー)**:
  - タイトル: 「予算設定・管理」
  - Leading（左側）: 「‹ 今日」アイコンボタン（タップでダッシュボードタブへ復帰 / またはPop）
  - Trailing（右側）: 「保存」ボタン（タップでキーボード解除 ＆ DB保存 ＆ 画面復帰）
- **画面全体のタッチ領域**:
  - `GestureDetector` による背景タップ検知。タップ時に即座に `FocusScope.of(context).unfocus()` を実行。
- **金額入力フィールド**:
  - `textInputAction: TextInputAction.done` を指定。
  - 入力完了時（`onSubmitted`）に自動でフォーカスを解除。

---

#### 3. 入力項目・キーボード操作要件

| 項目名 | 操作イベント | 挙動・フォーカス制御 | 画面遷移 |
| :--- | :--- | :--- | :--- |
| **画面背景** | タップ | `FocusScope.unfocus()` を呼び出し、テンキーを閉じる | 遷移なし（入力画面維持） |
| **金額入力欄** | 完了 (Done) アクション | `FocusScope.unfocus()` を呼び出し、テンキーを閉じる | 遷移なし（入力値保持） |
| **保存ボタン** | タップ | 1. キーボードを閉じる<br>2. DBを更新<br>3. トースト表示<br>4. ダッシュボードへ自動遷移 | 「今日」タブ（Index 0）または直前画面 |
| **戻るボタン (Leading)** | タップ | 1. キーボードを閉じる<br>2. ダッシュボードへ復帰 | 「今日」タブ（Index 0）または直前画面 |
| **下部タブバー** | 任意のタブタップ | 即座にキーボードを閉じて指定タブへ遷移 | 選択したタブ画面 |

---

#### 4. ビジネスロジック・バリデーション

1. **入力値の検証**:
   - 金額が未入力または 0 以下の場合は「有効な予算金額を入力してください」とエラーメッセージを表示し、保存と自動遷移を抑止する。
   - 最大金額は `99,999,999` 円。
2. **保存後の遷移遅延**:
   - 保存ボタン押下時、DB更新完了後に即座にタブ切り替えを行い、遷移先画面（ダッシュボード）上で「予算設定を保存しました」のスナックバーを表示する。これにより、保存された予算が即座に反映されたダッシュボードを確認できる。

---

#### 5. エラーハンドリング・エッジケース

1. **キーボード展開中のタブタップ**:
   - ユーザーがテンキー表示中にBottomNavigationBarの他タブ（「今日」「履歴」等）をタップした場合、キーボードのDismissとタブ切り替えが同時にスムーズに行われ、レイアウト崩れや描画遅延が発生しないこと。
2. **未保存時の別画面移動**:
   - ユーザーが保存ボタンを押さずに戻るボタンや別タブをタップした場合は、変更は破棄（または次回起動まで保持）され、画面遷移をブロックしない。

## 保存資料: budget-settings-navigation-ux / 詳細設計

移行元: `docs/implementation/features/budget-settings-navigation-ux.md`。旧節番号とコード例を保持。

### 予算設定画面 入力後画面遷移・キーボードUX詳細設計書 (budget-settings-navigation-ux)

#### 1. アーキテクチャ・設計概要
本設計は、予算設定画面（`BudgetSettingsScreen`）における「入力後の画面遷移不能」「キーボードが閉じない」問題を解消し、直感的で快適なナビゲーションとキーボードUXを提供するための詳細設計を定義する。

##### 解決方針
1. **グローバルナビゲーション状態の導入**:
   - `MainNavigationShell` の現在アクティブなタブインデックス（`currentIndex`）を Riverpod の `StateProvider`（`mainNavigationIndexProvider`）に昇格させる。
   - これにより、任意の画面（予算設定画面等）からプログラム経由で安全にタブ切り替え（今日ダッシュボードへの復帰）を可能にする。
2. **キーボード制御とフォーカス解除 (Unfocus)**:
   - 画面全体のルートウィジェットを `GestureDetector`（`HitTestBehavior.opaque`）でラップし、画面のあらゆる余白タップで即座にテンキーを閉じる。
   - `TextField` に `TextInputAction.done` を付与し、入力確定キー（Done/Enter）でもフォーカスを自動解除する。
3. **保存・戻るアクションの画面遷移フロー統合**:
   - 「保存」処理時および「戻る」ボタン押下時に、キーボードのフォーカスを解除した上で `Navigator.canPop(context)` を確認し、Pop または `mainNavigationIndexProvider` によるダッシュボード（Index 0）へのタブ切り替えを統一的に実行する。

---

#### 2. 状態管理設計 (State Management)

##### 2.1 ナビゲーションプロバイダー
`lib/core/providers/app_providers.dart` にタブインデックスを管理するプロバイダーを追加する。

```dart
/// メイン画面のタブインデックス状態管理プロバイダー
/// 0: 今日 (DailyExpenseDashboardScreen)
/// 1: 履歴 (ExpenseHistoryScreen)
/// 2: 予算 (BudgetSettingsScreen)
/// 3: カテゴリ (CategoryListScreen)
final mainNavigationIndexProvider = StateProvider<int>((ref) => 0);
```

##### 2.2 画面遷移ヘルパーメソッド
`BudgetSettingsScreen` 内で戻り先を動的に解決する共通ロジック:
```dart
void _navigateBack(BuildContext context, WidgetRef ref) {
  FocusScope.of(context).unfocus();
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    // タブとして表示されている場合は「今日」タブ(Index 0)に切り替え
    ref.read(mainNavigationIndexProvider.notifier).state = 0;
  }
}
```

---

#### 3. コンポーネント設計 (Presentation Layer)

##### 3.1 `BudgetSettingsScreen` の修正
- **背景タップ制御**:
  ```dart
  GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => FocusScope.of(context).unfocus(),
    child: Scaffold(...),
  )
  ```
- **AppBar Leading（戻る導線）**:
  ```dart
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
    tooltip: '今日へ戻る',
    onPressed: () => _navigateBack(context, ref),
  ),
  ```
- **金額入力 TextField**:
  ```dart
  TextField(
    controller: _amountController,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => FocusScope.of(context).unfocus(),
    ...
  )
  ```
- **保存ボタン (`_saveBudget`) フロー**:
  ```dart
  Future<void> _saveBudget() async {
    FocusScope.of(context).unfocus();
    final rawText = _amountController.text.replaceAll(',', '').trim();
    final amount = int.tryParse(rawText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効な予算金額（1円以上）を入力してください')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    await (db.update(db.budgets)).write(...);

    if (!mounted) return;
    _navigateBack(context, ref);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('予算設定を保存しました')),
    );
  }
  ```

##### 3.2 `MainNavigationShell` の修正
- `_currentIndex` をローカル State ではなく `ref.watch(mainNavigationIndexProvider)` から購読する。
- タブタップ時:
  ```dart
  onTap: (idx) {
    FocusScope.of(context).unfocus();
    ref.read(mainNavigationIndexProvider.notifier).state = idx;
  }
  ```

---

#### 4. テスト方針

1. **キーボード解除テスト (`budget_settings_screen_test.dart`)**:
   - テキスト入力フィールドにフォーカスを当てた後、画面背景タップでフォーカスが外れる（`hasPrimaryFocus == false`）ことを検証。
2. **保存＆タブ遷移テスト (`budget_settings_screen_test.dart`)**:
   - 金額を入力して「保存」ボタンをタップした際、DBの `budgets` テーブルが更新され、`mainNavigationIndexProvider` の値が `0`（今日タブ）に変更されることを検証。
3. **戻るボタンテスト**:
   - Leading の戻るボタンタップ時に、`mainNavigationIndexProvider` の値が `0` に切り替わることを検証。
