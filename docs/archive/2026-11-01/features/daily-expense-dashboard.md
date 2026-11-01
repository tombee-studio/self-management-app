# 日次支出ダッシュボード 設計（既存資料の統合）

- **バージョン**: v0.1.0
- **ステータス**: draft
- **資料区分**: 過去資料（現行仕様・工程ゲートの対象外）
- **整理日**: 2026-11-01（JST）

対応要求: [要求案](../../../req/features/daily-expense-dashboard.md)。要求がdraftのため、本書は未確定の既存設計資料として保管する。

削除同期・取り消しの関連資料: [クラウド同期](../../../spec/features/aws-cloud-database-sync.md)。未確定の削除方式は[DOC-02](../../../STATUS.md)で管理する。

## 保存時点の移行範囲と確定条件

既存の仕様・詳細設計を同一文書へ移した。以下の保存節は当時の案であり、実装との一致・検証完了を保証しない。重複や矛盾は採用判断をせず保持し、[差分一覧](../../../STATUS.md)へ記録した。REQ確定後に振る舞い・データモデル・状態管理・異常系を同期し、レビューする。

## 保存資料: daily-expense-dashboard / 仕様

移行元: `docs/spec/features/daily-expense-dashboard.md`。旧節番号とコード例を保持。

### 日次支出ダッシュボード (daily-expense-dashboard) 仕様書

#### 1. 目的・概要
ユーザーが当日（または選択した任意の日付）に使った支出総額・カテゴリ別内訳・明細一覧をダッシュボード上でひと目で直感的に把握できるようにし、日常的な使いすぎの防止と支出管理の習慣化を支援する。

---

#### 2. ユーザーフロー・画面要件

##### 2.1 ユーザーフロー
1. アプリを起動すると、デフォルトで「今日」の日次ダッシュボードが表示される。
2. 画面上部の日付セレクタから前日／翌日への切り替え、または「今日」ボタンで当日に復帰できる。
3. 当日の支出合計金額と、設定されている場合は目標日次予算との進捗を確認できる。
4. カテゴリ別内訳（割合バーまたはミニチャート）でどこにお金を使ったかを把握できる。
5. 支出明細リストで各支払いの詳細を確認でき、明細タップで編集・削除モーダルを開くことができる。
6. 右下のクイック追加ボタン（FAB）をタップして、新規支出入力画面を開くことができる。

##### 2.2 画面コンポーネント要件
- **画面構成および画面仕様 (draw.io)**: [docs/spec/screens.drawio](../../../spec/screens.drawio) （タブ: `日次支出ダッシュボード`）
- **ヘッダー / 日付セレクタ**:
  - 表示形式: `YYYY年M月D日 (曜日)`（例: `2026年10月3日(土)`）
  - 前日移動ボタン（`‹`）、翌日移動ボタン（`›`）
  - 今日ではない日付を表示中の場合、「今日へ戻る」ボタンを表示
- **日次サマリーカード**:
  - 本日の支出合計金額（大文字ハイライト表示、例: `¥4,580`）
  - 目標予算対比（目標日次予算設定時: 予算残額および進捗率バー）
- **カテゴリ別内訳セクション**:
  - カテゴリごとの合計金額および全体支出に対する比率（%）
  - カテゴリカラーに応じた色分けバー表示
- **支出明細リスト**:
  - 選択日の支出を登録時刻降順（最新順）で一覧表示
  - 各行要素: カテゴリアイコン、カテゴリ名、メモ/店舗名、登録時刻（`HH:mm`）、金額
  - 空状態（支出0件時）: 「この日の支出はまだありません」のイラスト/テキスト＋「支出を追加する」ボタン
- **クイック追加ボタン (FAB)**:
  - 画面右下に固定フローティング配置（アクセントカラー、`+` アイコン）

---

#### 3. 入力項目・バリデーション
本画面は主に参照画面であるが、日付変更および明細操作時の制約を定義する。

- **日付選択**:
  - 未来日付の選択: 許可する（未来の予定支出や定期支出の確認のため。データがなければ0件表示）。
  - 有効範囲: 1970-01-01 以降。
- **金額表示フォーマット**:
  - 整数表示（日本円基準: `¥#,##0`）
  - 負の金額（返金・取消等）がある場合の表記: `-¥#,##0`（または赤字表記）

---

#### 4. ビジネスロジック・計算ルール

##### 4.1 当日集計ロジック
- **集計対象**:
  - 選択中の日付におけるローカルタイム `00:00:00` 以上 `23:59:59.999` 以下の支出データ。
- **日次合計金額 ($Total_{day}$)**:
  $$Total_{day} = \sum_{i=1}^{n} \text{Amount}_i$$
- **カテゴリ別集計 ($Total_{cat}$)**:
  - カテゴリごとに金額を合算し、降順でソート。
  - 各カテゴリの割合: $(Total_{cat} / Total_{day}) \times 100 \ (\%)$ （$Total_{day} > 0$ の場合のみ計算）

##### 4.2 目標予算との進捗計算（日次目標予算 $Budget_{day}$ が存在する場合）
- 残額: $Remaining = Budget_{day} - Total_{day}$
- 進捗率: $Progress = \min(100, (Total_{day} / Budget_{day}) \times 100)$
- 超過判定: $Total_{day} > Budget_{day}$ の場合は警告色（アクセント赤/オレンジ）で表示。

---

#### 5. エラーハンドリング・エッジケース

- **大金・高桁数の表示**:
  - 8桁以上（1,000万円以上）の金額でも表示が途切れないよう、フォントサイズの自動スケーリング（Auto-sizing text）または折り返し対応を実施。
- **データ取得失敗 / ストレージエラー**:
  - データ取得に失敗した場合はエラーメッセージと「再試行」ボタンを表示。
- **オフライン動作**:
  - ローカルファーストで設計し、オフライン環境でも瞬時に表示・更新可能とする。

## 保存資料: daily-expense-dashboard / 詳細設計

移行元: `docs/implementation/features/daily-expense-dashboard.md`。旧節番号とコード例を保持。

### 日次支出ダッシュボード (daily-expense-dashboard) 詳細設計書

#### 1. 概要
- **対応仕様書**: [docs/spec/features/daily-expense-dashboard.md](../../../spec/features/daily-expense-dashboard.md)
- **目的**: 日次支出ダッシュボードを表示するためのデータ構造、コンポーネント構成、状態管理、および集計ロジックを設計する。

---

#### 2. データモデル設計

##### 2.1 エンティティ定義

```typescript
// 支出カテゴリ
export interface Category {
  id: string;
  name: string;
  iconName: string;
  colorHex: string; // 例: '#FF6B6B'
  sortOrder: number;
}

// 支出明細
export interface Expense {
  id: string;
  amount: number;       // 正の整数（円）
  categoryId: string;
  memo?: string;        // 支払いメモ・店舗名等
  spentAt: string;      // ISO 8601 文字列 (例: '2026-10-03T14:30:00.000Z')
  createdAt: string;
  updatedAt: string;
}

// カテゴリ別集計項目
export interface CategoryBreakdownItem {
  category: Category;
  totalAmount: number;
  percentage: number;   // 0.0 〜 100.0
}

// 日次支出サマリー
export interface DailyExpenseSummary {
  selectedDate: string; // YYYY-MM-DD
  totalAmount: number;
  dailyBudget?: number; // 目標日次予算（設定されている場合）
  remainingBudget?: number;
  breakdown: CategoryBreakdownItem[];
  expenses: Expense[];
}
```

---

#### 3. コンポーネント構成（UIアーキテクチャ）
- **画面構成および画面仕様 (draw.io)**: [docs/spec/screens.drawio](../../../spec/screens.drawio) （タブ: `日次支出ダッシュボード`）

```text
DashboardScreen (トップ画面)
├── DateSelectorBar (日付切り替え・カレンダー選択)
├── DailySummaryCard (当日の合計支出金額、日次予算との進捗バー)
├── CategoryBreakdownSection (カテゴリ別割合バー・内訳リスト)
├── DailyExpenseListView (当日の支出明細一覧)
│   ├── ExpenseItemCard (各支出アイテム: アイコン、メモ、時刻、金額)
│   └── EmptyExpenseView (支出0件時のプレースホルダー)
└── QuickAddFloatingButton (画面右下固定の支出入力起動ボタン)
```

##### 3.1 各コンポーネントの責務
- `DashboardScreen`: 選択日状態の管理、データ取得トリガー、子コンポーネントのレイアウト
- `DateSelectorBar`: 前日・翌日ボタンタップのハンドリング、当日の表示、当日復帰ボタンの制御
- `DailySummaryCard`: 当日合計金額のフォーマット表示、予算比較ロジックに基づくゲージ描画
- `CategoryBreakdownSection`: カテゴリ比率に応じた色分けバーの描画（FlexまたはCSS Grid）
- `DailyExpenseListView`: 支出リストの仮想化/スクロール表示、アイテムタップ時の詳細モーダル起動
- `QuickAddFloatingButton`: 新規作成モーダル（支出登録機能）の起動イベント発火

---

#### 4. 状態管理＆ロジック層

##### 4.1 集計サービス / ユーティリティ (`calculateDailySummary`)
純粋関数として実装し、徹底した単体テストを担保する。

```typescript
export function calculateDailySummary(
  targetDate: Date,
  expenses: Expense[],
  categories: Map<string, Category>,
  dailyBudget?: number
): DailyExpenseSummary {
  // 1. 指定日の 00:00:00 〜 23:59:59 に含まれる支出をフィルタリング
  const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0);
  const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59, 999);

  const filtered = expenses.filter(e => {
    const d = new Date(e.spentAt);
    return d >= startOfDay && d <= endOfDay;
  });

  // 2. 支出合計を算出
  const totalAmount = filtered.reduce((sum, item) => sum + item.amount, 0);

  // 3. カテゴリごとの合算
  const categoryMap = new Map<string, number>();
  for (const item of filtered) {
    categoryMap.set(item.categoryId, (categoryMap.get(item.categoryId) || 0) + item.amount);
  }

  // 4. カテゴリ別内訳リスト生成（降順ソート）
  const breakdown: CategoryBreakdownItem[] = Array.from(categoryMap.entries()).map(([catId, amount]) => {
    const category = categories.get(catId) || {
      id: catId,
      name: '未分類',
      iconName: 'help_outline',
      colorHex: '#868e96',
      sortOrder: 999,
    };
    return {
      category,
      totalAmount: amount,
      percentage: totalAmount > 0 ? (amount / totalAmount) * 100 : 0,
    };
  }).sort((a, b) => b.totalAmount - a.totalAmount);

  // 5. 予算対比計算
  const remainingBudget = dailyBudget !== undefined ? dailyBudget - totalAmount : undefined;

  return {
    selectedDate: formatDateIso(targetDate),
    totalAmount,
    dailyBudget,
    remainingBudget,
    breakdown,
    expenses: filtered.sort((a, b) => new Date(b.spentAt).getTime() - new Date(a.spentAt).getTime()),
  };
}
```

---

#### 5. データアクセス層（リポジトリ設計）

```typescript
export interface ExpenseRepository {
  /** 指定された期間内の支出データを取得（またはストリーム購読） */
  getByDateRange(startDate: Date, endDate: Date): Promise<Expense[]>;
  /** 支出を1件追加 */
  add(expense: Omit<Expense, 'id' | 'createdAt' | 'updatedAt'>): Promise<Expense>;
  /** 支出を更新 */
  update(id: string, expense: Partial<Expense>): Promise<Expense>;
  /** 支出を削除 */
  delete(id: string): Promise<void>;
}
```

---

#### 6. テスト設計

##### 6.1 単体テスト (Unit Test)
- `calculateDailySummary`:
  - 支出が0件の場合の出力（合計0、breakdown空配列、expenses空配列）
  - 同一カテゴリ・複数カテゴリの複数明細が正しく合算・ソートされること
  - 日付境界（前日23:59:59、当日00:00:00、当日23:59:59、翌日00:00:00）の支出が正しく識別されること
  - 予算超過時（$totalAmount > dailyBudget$）に残額がマイナス値になること

##### 6.2 UI/コンポーネントテスト
- 前日・翌日ボタン押下で表示日付が1日進む/戻ること
- 支出0件時に空状態メッセージが表示されること
- 各明細の金額がカンマ区切り（`¥#,##0`）で表示されること
