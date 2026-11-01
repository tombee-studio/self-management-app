# 支出履歴・過去一覧 設計（既存資料の統合）

- **バージョン**: v0.1.0
- **ステータス**: draft
- **資料区分**: 過去資料（現行仕様・工程ゲートの対象外）
- **整理日**: 2026-11-01（JST）

対応要求: [要求案](../../../req/features/expense-history-list.md)。要求がdraftのため、本書は未確定の既存設計資料として保管する。

## 保存時点の移行範囲と確定条件

既存の仕様・詳細設計を同一文書へ移した。以下の保存節は当時の案であり、実装との一致・検証完了を保証しない。重複や矛盾は採用判断をせず保持し、[差分一覧](../../../STATUS.md)へ記録した。REQ確定後に振る舞い・データモデル・状態管理・異常系を同期し、レビューする。

## 保存資料: expense-history-list / 仕様

移行元: `docs/spec/features/expense-history-list.md`。旧節番号とコード例を保持。

### 支出履歴・過去一覧機能 (expense-history-list) 仕様書

#### 1. 目的・概要
ユーザーが「今日（当日）」の支出明細にとどまらず、過去数日・数週間・数ヶ月前の支出履歴をスムーズに一覧表示・検索・振り返ることができるようにする。
日別タイムライン形式および月間カレンダー連動形式の2つの閲覧モードを提供し、過去の支出動向の把握や記録内容の確認・編集を直感的に行えるようにする。

---

#### 2. ユーザーフロー・画面要件

##### 2.1 ユーザーフロー
1. **履歴の閲覧**:
   - ユーザーはボトムナビ（またはサイドバー）の「カレンダー / 履歴」タブをタップする。
   - 初期表示では当月・直近の支出が日付ごとにグループ化されたタイムライン形式で表示される。
2. **過去の支出を遡る**:
   - 下方向にスクロールすることで、過去の日付の支出明細（日付ヘッダー＋日ごとの小計合計＋明細リスト）を連続して閲覧できる。
3. **カレンダービューへの切り替え**:
   - 画面上部の切り替えタブで「カレンダー」を選択すると、月間カレンダーが表示され、日付ごとの支出合計金額がカレンダーセル内に視覚表示される。
   - カレンダー上の日付セルをタップすると、その日に発生した支出明細リストが下部（タブレットでは右ペイン）に即座に表示される。
4. **検索と絞り込み**:
   - 検索バーにキーワード（店舗名・メモ）を入力して即座に該当明細をインクリメンタル検索できる。
   - カテゴリチップ（食費、日用品、交通等）や決済手段（Apple Pay自動記録 / 手動入力）で絞り込みが可能。
5. **明細の編集・削除**:
   - 任意の明細をタップすると詳細・編集モーダル（タブレットではインライン）が開き、金額・カテゴリ・メモの修正や削除を行える。

##### 2.2 画面コンポーネント要件
- **画面構成および画面仕様 (draw.io)**: [docs/spec/screens.drawio](../../../spec/screens.drawio) （タブ: `支出履歴・カレンダー一覧`）
  - **上部ツールバー**: 表示切替タブ（リスト / カレンダー）、月セレクタ（`< 2026年10月 >`）、月間支出総額
  - **検索・フィルターバー**: キーワード入力フィールド、カテゴリ横スクロールチップ
  - **リストビュー (タイムライン)**:
    - 日付セクションヘッダー: `2026年10月3日 (土)`、件数（例: `3件`）、日別小計（例: `¥4,580`）
    - 明細カード: カテゴリアイコン、店舗名/メモ、登録時刻、決済手段バッジ（🍎Pay等）、金額
  - **カレンダービュー**:
    - 月間グリッド（日〜土）
    - 各日付セル: 日付数値、支出小計（支出なし日は非表示、予算超過日は赤文字）、選択中ハイライト
    - 選択日の明細一覧シート（下部固定またはハーフシート）

---

#### 3. ビジネスロジック・処理ルール

##### 3.1 日付別グルーピングと小計集計
- ローカルDB（SQLite）内の全支出データを `spent_at` 降順で読み出し、端末のローカルタイムゾーン基準の `YYYY-MM-DD` 単位でグループ化する。
- 各グループの小計は、その日付に含まれる明細の `amount` の総和。
- 同一グループ内では `spent_at` 降順（最新の支払いが上）でソート。

##### 3.2 フィルタリングルール
- 複数条件（AND条件）での絞り込みに対応:
  - 期間: 指定月（`2026-10-01` 〜 `2026-10-31`）または全期間
  - カテゴリ: 選択されたカテゴリID（複数選択可能、未選択時は全件）
  - キーワード: 店舗名（`merchantName`）またはメモ（`memo`）の部分一致（大小文字・全角半角を無視）
  - 決済ソース: `sourcePlatform`（すべて / `apple_pay` のみ / 手動登録のみ）

##### 3.3 ページネーション・パフォーマンス
- 過去データが数千件規模になっても快適に動作するよう、月単位（または50件単位）で遅延読み込み（Lazy Loading / Infinite Scroll）を行う。
- カレンダービューでは当月＋前後1ヶ月分のキャッシュを保持し、月移動時の描画ラグをゼロにする。

---

#### 4. エラーハンドリング・エッジケース

- **検索結果 0 件時**:
  - 「条件に一致する支出が見つかりませんでした」のイラストと、「検索条件をクリア」ボタンを表示。
- **データ未登録の過去日**:
  - カレンダー上では空欄として扱い、日付タップ時は「この日の支出はありません」＋「支出を追加」ボタンを表示。
- **完全オフライン動作**:
  - すべての検索・グルーピング・集計はローカルSQLiteのインデックスを活用して端末内で完結（通信不要）。

## 保存資料: expense-history-list / 詳細設計

移行元: `docs/implementation/features/expense-history-list.md`。旧節番号とコード例を保持。

### 支出履歴・過去一覧機能 (expense-history-list) 詳細設計書

#### 1. 概要
- **対応仕様書**: [docs/spec/features/expense-history-list.md](../../../spec/features/expense-history-list.md)
- **採用技術**: Flutter (Dart) / drift (SQLite) / Riverpod
- **目的**: 大量の過去支出データを高速に検索・グループ化し、タイムラインリストおよび月間カレンダーとして提供するためのデータアクセス・状態管理・UIコンポーネント設計を定義する。

---

#### 2. データモデル＆データアクセス層設計 (drift / SQLite)

##### 2.1 日別グループ集計モデル

```dart
// 日別支出グループ
class DailyExpenseGroup {
  final DateTime date;            // YYYY-MM-DD (00:00:00)
  final int totalAmount;          // 日別小計（円）
  final int count;                // 明細件数
  final List<ExpenseItemData> expenses; // 当該日の支出リスト

  const DailyExpenseGroup({
    required this.date,
    required this.totalAmount,
    required this.count,
    required this.expenses,
  });
}

// フィルター条件
class ExpenseFilter {
  final DateTime? startMonth;     // 対象月
  final Set<String> categoryIds;  // 選択カテゴリ（空なら全件）
  final String? searchQuery;      // 検索キーワード
  final String? sourcePlatform;   // 'apple_pay' 等

  const ExpenseFilter({
    this.startMonth,
    this.categoryIds = const {},
    this.searchQuery,
    this.sourcePlatform,
  });

  bool get isEmpty =>
      startMonth == null &&
      categoryIds.isEmpty &&
      (searchQuery == null || searchQuery!.isEmpty) &&
      sourcePlatform == null;
}
```

##### 2.2 drift による最適化クエリ (`ExpenseDao`)

```dart
@DriftAccessor(tables: [Expenses, Categories])
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(AppDatabase db) : super(db);

  /** フィルター条件に基づく支出ストリーム取得（リアクティブ） */
  Stream<List<ExpenseWithCategory>> watchFilteredExpenses(ExpenseFilter filter) {
    final query = select(expenses).join([
      innerJoin(categories, categories.id.equalsExp(expenses.categoryId)),
    ]);

    // 期間絞り込み
    if (filter.startMonth != null) {
      final start = DateTime(filter.startMonth!.year, filter.startMonth!.month, 1);
      final end = DateTime(filter.startMonth!.year, filter.startMonth!.month + 1, 0, 23, 59, 59);
      query.where(expenses.spentAt.isBetweenValues(start, end));
    }

    // カテゴリ絞り込み
    if (filter.categoryIds.isNotEmpty) {
      query.where(expenses.categoryId.isIn(filter.categoryIds));
    }

    // キーワード部分一致検索（店舗名 or メモ）
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final q = '%${filter.searchQuery}%';
      query.where(expenses.merchantName.like(q) | expenses.memo.like(q));
    }

    // 決済プラットフォーム絞り込み
    if (filter.sourcePlatform != null) {
      query.where(expenses.sourcePlatform.equals(filter.sourcePlatform!));
    }

    query.orderBy([OrderingTerm.desc(expenses.spentAt)]);

    return query.watch().map((rows) => rows.map((r) => ExpenseWithCategory(
      expense: r.readTable(expenses),
      category: r.readTable(categories),
    )).toList());
  }
}
```

---

#### 3. 状態管理設計 (Riverpod)

```text
[ExpenseFilterNotifier] ──────────┐ (フィルター条件 State)
                                  ▼
[FilteredExpensesStreamProvider] (driftからリアルタイム購読)
                                  ▼
[GroupedExpensesProvider] (純粋関数で日付ごとにグルーピング計算)
         │
         ├────────────────────────┬────────────────────────┐
         ▼                        ▼                        ▼
[TimelineListView]        [MonthlyCalendarView]     [TotalSummaryBadge]
```

##### 3.1 グルーピングロジック（純粋関数）
```dart
List<DailyExpenseGroup> groupExpensesByDate(List<ExpenseWithCategory> items) {
  final map = <DateTime, List<ExpenseWithCategory>>{};
  for (final item in items) {
    final d = item.expense.spentAt;
    final dateOnly = DateTime(d.year, d.month, d.day);
    map.putIfAbsent(dateOnly, () => []).add(item);
  }

  return map.entries.map((e) {
    final subtotal = e.value.reduce((acc, curr) => acc + curr.expense.amount);
    return DailyExpenseGroup(
      date: e.key,
      totalAmount: subtotal,
      count: e.value.length,
      expenses: e.value,
    );
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}
```

---

#### 4. UIコンポーネントツリー

```text
HistoryScreen
├── HistoryHeaderToolbar (月選択, リスト/カレンダー切替タブ, 月間合計)
├── SearchAndFilterBar
│   ├── SearchTextField (インクリメンタル検索)
│   └── CategoryFilterChips (横スクロールカテゴリ選択)
└── IndexedStack (切替)
    ├── [0] TimelineListView (日別ヘッダー + 支出カード一覧)
    │     └── CustomScrollView + SliverStickyHeader
    └── [1] MonthlyCalendarView (月間カレンダー + 選択日明細一覧)
          ├── TableCalendar (日付セル内に小計金額描画)
          └── SelectedDateExpenseSheet (選択日の明細)
```

---

#### 5. テスト設計

##### 5.1 単体テスト (Unit Test)
- `groupExpensesByDate`:
  - 複数日の支出データが同一日に正しくグループ化されること。
  - 各日の小計金額が正確に計算されること。
  - 最新の日付が先頭に降順ソートされること。
- `ExpenseFilter`:
  - キーワード検索とカテゴリ絞り込みの複合条件が正しく機能すること。

##### 5.2 ウィジェットテスト (Widget Test)
- リスト / カレンダー表示のタブ切り替えで画面が正しく再描画されること。
- カレンダーの日付タップで下部シートに該当日の明細が表示されること。
- 検索入力時に一致する明細のみが表示されること。
