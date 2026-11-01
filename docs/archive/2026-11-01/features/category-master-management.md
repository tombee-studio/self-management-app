# カテゴリマスター管理 設計（既存資料の統合）

- **バージョン**: v0.1.0
- **ステータス**: draft
- **資料区分**: 過去資料（現行仕様・工程ゲートの対象外）
- **整理日**: 2026-11-01（JST）

対応要求: [要求案](../../../req/features/category-master-management.md)。要求がdraftのため、本書は未確定の既存設計資料として保管する。

## 保存時点の移行範囲と確定条件

既存の仕様・詳細設計を同一文書へ移した。以下の保存節は当時の案であり、実装との一致・検証完了を保証しない。重複や矛盾は採用判断をせず保持し、[差分一覧](../../../STATUS.md)へ記録した。REQ確定後に振る舞い・データモデル・状態管理・異常系を同期し、レビューする。

## 保存資料: category-master-management / 仕様

移行元: `docs/spec/features/category-master-management.md`。旧節番号とコード例を保持。

### カテゴリマスター管理機能 (category-master-management) 仕様書

#### 1. 目的・概要
ユーザー自身の生活スタイルや家計管理の方針に合わせて、支出カテゴリを自由に追加・編集・並び替え・削除できるようにする。
豊富なアイコンとカラーパレットによる直感的なカスタマイズを提供し、削除時の既存データ保護（「未分類」への安全な自動移行）によりローカルDBの整合性を完全に維持する。

---

#### 2. ユーザーフロー・画面要件

##### 2.1 ユーザーフロー

###### A. カテゴリ一覧の閲覧と並び替え
1. アプリ設定メニュー、または支出入力モーダルの「＋他」から「カテゴリ管理画面」を開く。
2. 登録済みカテゴリが並び順に従ってリスト表示される（アイコン、カラー、カテゴリ名、紐づく支出件数）。
3. リストのハンドルを長押しドラッグ＆ドロップ（`ReorderableListView`）することで、支出登録時の並び順を自由に並び替えることができる。

###### B. カテゴリの新規作成・編集
1. 右上の「＋」ボタン、または既存カテゴリ行をタップすると「カテゴリ設定シート」が開く。
2. **カテゴリ名**: テキスト入力（例:「推し活」「ペット費」）。
3. **アイコン選択**: グリッド表示された生活・支出関連アイコン（食事、日用品、乗り物、エンタメ、医療、書籍、ペット、趣味など約40種）から1タップで選択。
4. **カラー選択**: 厳選された16色のモダンパレット（レッド、コーラル、アンバー、エメラルド、シアン、インディゴ、バイオレット、ピンク等）から選択。
5. 上部のリアルタイムプレビューで見た目を確認し、「保存」をタップして完了。

###### C. カテゴリの削除と既存明細保護
1. カテゴリ行のスワイプまたはゴミ箱アイコンをタップする。
2. **紐づく支出が存在する場合**:
   - 警告ダイアログ表示: `「このカテゴリには ○ 件の支出データが登録されています。削除すると、これらの支出はすべて『未分類』カテゴリに付け替えられます。削除してよろしいですか？」`
3. ユーザーが「削除する」を承認した場合、ローカルDBの全明細の `category_id` を安全に「未分類」へ一括更新した上でカテゴリレコードを削除する。
4. **システム保護**: デフォルトの「未分類 (Uncategorized)」カテゴリは編集・削除不可（削除ボタン非活性）。

##### 2.2 画面コンポーネント要件
- **画面構成および画面仕様 (draw.io)**: [docs/spec/screens.drawio](../../../spec/screens.drawio) （タブ: `カテゴリ管理画面` / SCR-007）
- **ヘッダー**: 画面タイトル「カテゴリ管理」、戻るボタン、新規追加ボタン（`＋`）
- **並び替え対応カテゴリルール**:
  - ドラッグハンドル（`≡` アイコン）
  - カテゴリアイコンバッジ（選択カラー背景＋白抜きアイコン）
  - カテゴリ名・登録支出件数表示
  - 編集ボタン、削除ボタン
- **編集・追加モーダル (CategoryEditSheet)**:
  - リアルタイムプレビューバッジ
  - カテゴリ名称入力フィールド
  - アイコンピッカーグリッド（スクロール可能）
  - カラーパレットサークル（16色選択）
  - 保存・キャンセルボタン

---

#### 3. 入力項目・バリデーション

| 項目名 | 必須 | 形式 / 制約 | 初期値 | エラー条件・挙動 |
| :--- | :---: | :--- | :--- | :--- |
| **カテゴリ名** | ○ | 文字列（`1` 〜 `20` 文字） | 空文字 | 未入力、空白のみ、または20文字超過時は保存不可。既存カテゴリ名と重複する場合は「既に同名のカテゴリが存在します」とエラー表示。 |
| **アイコン** | ○ | アイコン識別子（`String`） | `category_default` | 未選択不可。 |
| **カラー** | ○ | 16進数カラーコード（HEX `String`） | `#6366F1` | 未選択不可。 |
| **表示順** | ○ | 整数（`sort_order`） | 末尾インデックス | ドラッグ＆ドロップ時に自動再採番。 |

---

#### 4. ビジネスロジック・計算ルール

##### 4.1 初期シードデータ
アプリ初回起動時、以下の標準カテゴリが自動的に drift DB に登録される:
1. 🍽️ 食費 (`#EF4444`)
2. 🛒 日用品 (`#10B981`)
3. 🚃 交通費 (`#3B82F6`)
4. ☕ カフェ・外食 (`#F59E0B`)
5. 👔 衣服・美容 (`#EC4899`)
6. 🏥 医療・健康 (`#06B6D4`)
7. 🎉 趣味・娯楽 (`#8B5CF6`)
8. 🏠 住まい・通信 (`#64748B`)
9. 📁 未分類 (システム予約・削除不可) (`#94A3B8`)

##### 4.2 削除時カスケード更新トランザクション
カテゴリ $C_{target}$ の削除実行時、drift DB の単一トランザクション内で以下を不可分に実行する:
```sql
BEGIN TRANSACTION;
-- 1. 紐づく支出明細を「未分類」に移行
UPDATE expenses
SET category_id = 'cat_uncategorized', updated_at = CURRENT_TIMESTAMP
WHERE category_id = :target_id;

-- 2. カテゴリを削除
DELETE FROM categories WHERE id = :target_id;
COMMIT;
```
これにより、過去の支出合計金額や日次ダッシュボードのデータ整合性が完全に保護される。

---

#### 5. エラーハンドリング・エッジケース

1. **同名カテゴリの重複防止**:
   - 名称入力フィールドの変更時に重複チェックを行い、同名がある場合はリアルタイムで赤字警告を表示。
2. **ドラッグ並び替えの整合性**:
   - ドラッグ途中でアプリが終了した場合でも矛盾が生じないよう、並び替え確定時（`onReorder` 完了時）に一括トランザクションで各レコードの `sort_order` を連番更新。

## 保存資料: category-master-management / 詳細設計

移行元: `docs/implementation/features/category-master-management.md`。旧節番号とコード例を保持。

### カテゴリマスター管理機能 (category-master-management) 詳細設計書

#### 1. 概要・アーキテクチャ構成
本機能は、ユーザーによる支出カテゴリの追加・編集・並び替え（ドラッグ＆ドロップ）・削除、および削除時のデータ整合性保護（未分類移行トランザクション）と初期シードデータ注入を提供します。

---

#### 2. コンポーネント構成・UIツリー

```
lib/features/category/
├── domain/
│   └── models/
│       ├── category_item.dart          # カテゴリエンティティモデル
│       └── preset_palette.dart         # アイコン定数・16色プリセット定義
├── data/
│   ├── database/
│   │   └── category_seed_data.dart     # 初回シードデータ定義
│   └── repositories/
│       └── category_repository.dart    # drift DB CRUD＆カスケードトランザクション
└── presentation/
    ├── controllers/
    │   └── category_list_controller.dart # 並び替え・編集状態管理
    ├── screens/
    │   └── category_list_screen.dart   # カテゴリ一覧画面 (SCR-007)
    └── widgets/
        ├── category_reorder_tile.dart  # ドラッグ並び替え対応行ウィジェット
        ├── category_edit_sheet.dart    # 追加・編集ボトムシート
        ├── icon_picker_grid.dart       # アイコン選択グリッド (40種)
        └── color_picker_palette.dart   # 16色カラーサークル
```

---

#### 3. データモデル・テーブル定義 (drift)

##### 3.1 テーブル定義
```dart
class Categories extends Table {
  TextColumn get id => text()();                               // UUID v4 または 'cat_uncategorized'
  TextColumn get name => text().withLength(min: 1, max: 20)(); // カテゴリ名
  TextColumn get iconKey => text()();                         // アイコン識別文字列 (例: 'restaurant', 'shopping_bag')
  TextColumn get colorHex => text()();                        // カラーコード (例: '#EF4444')
  IntColumn get sortOrder => integer()();                     // 表示順序 (0, 1, 2, ...)
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))(); // システム予約（未分類）フラグ
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

##### 3.2 初期シードデータ (`category_seed_data.dart`)
```dart
const defaultCategories = [
  CategoryItem(id: 'cat_food', name: '食費', iconKey: 'restaurant', colorHex: '#EF4444', sortOrder: 0),
  CategoryItem(id: 'cat_daily', name: '日用品', iconKey: 'shopping_bag', colorHex: '#10B981', sortOrder: 1),
  CategoryItem(id: 'cat_trans', name: '交通費', iconKey: 'train', colorHex: '#3B82F6', sortOrder: 2),
  CategoryItem(id: 'cat_cafe', name: 'カフェ・外食', iconKey: 'local_cafe', colorHex: '#F59E0B', sortOrder: 3),
  CategoryItem(id: 'cat_cloth', name: '衣服・美容', iconKey: 'checkroom', colorHex: '#EC4899', sortOrder: 4),
  CategoryItem(id: 'cat_med', name: '医療・健康', iconKey: 'medical_services', colorHex: '#06B6D4', sortOrder: 5),
  CategoryItem(id: 'cat_hobby', name: '趣味・娯楽', iconKey: 'sports_esports', colorHex: '#8B5CF6', sortOrder: 6),
  CategoryItem(id: 'cat_house', name: '住まい・通信', iconKey: 'home', colorHex: '#64748B', sortOrder: 7),
  CategoryItem(id: 'cat_uncategorized', name: '未分類', iconKey: 'folder', colorHex: '#94A3B8', sortOrder: 999, isSystem: true),
];
```

---

#### 4. ロジック・トランザクション設計

##### 4.1 並び替え更新ロジック (`ReorderableListView`)
```dart
Future<void> reorderCategories(int oldIndex, int newIndex) async {
  if (oldIndex < newIndex) {
    newIndex -= 1;
  }
  // リストの順序を入れ替えて、各カテゴリに新しい sortOrder を採番
  final items = List.of(state.categories);
  final movedItem = items.removeAt(oldIndex);
  items.insert(newIndex, movedItem);

  // drift DB で一括更新
  await _repository.batchUpdateSortOrder(
    items.asMap().entries.map((e) => (id: e.value.id, order: e.key)).toList(),
  );
}
```

##### 4.2 削除保護トランザクション (`safeDeleteCategory`)
```dart
Future<void> safeDeleteCategory(String targetCategoryId) async {
  await database.transaction(() async {
    // 1. 対象カテゴリに紐づく全支出を「未分類」に一括更新
    await (update(expenses)..where((tbl) => tbl.categoryId.equals(targetCategoryId)))
        .write(ExpensesCompanion(
          categoryId: const Value('cat_uncategorized'),
          updatedAt: Value(DateTime.now()),
        ));

    // 2. 予算配分テーブルに対象カテゴリの設定があれば削除
    await (delete(categoryBudgets)..where((tbl) => tbl.categoryId.equals(targetCategoryId))).go();

    // 3. カテゴリレコードを削除
    await (delete(categories)..where((tbl) => tbl.id.equals(targetCategoryId))).go();
  });
}
```

---

#### 5. UIコンポーネント詳細

- **`ReorderableListView`**:
  - `buildDefaultDragHandles: false` を指定し、左端の `≡` ハンドルをドラッグした時のみ並び替えをトリガー（誤スワイプ・スクロール競合防止）。
  - 「未分類」行はドラッグ不可・最下部に固定。
- **`IconPickerGrid`**:
  - 食事、ショッピング、移動、エンタメ、通信、生活、ペット、教育など 40種の主要生活アイコンを 8列×5行 のスクロールグリッドで表示。
- **`ColorPickerPalette`**:
  - 視認性とコントラスト比を考慮した 16色のモダンパレット（Tailwind 500系ベース）。タップで選択カラーにチェックマークアニメーション。

---

#### 6. テスト計画

1. **カスケード削除単体テスト (`test/unit/category_repository_test.dart`)**:
   - 支出が紐づいているカテゴリを削除した際、支出データの `category_id` が `cat_uncategorized` に安全に更新されること
   - システムカテゴリ（`cat_uncategorized`）の削除が例外で防がれること
2. **並び替えバッチ更新テスト (`test/unit/category_reorder_test.dart`)**:
   - 並び替え後に各レコードの `sortOrder` が一意の連番で永続化されること
3. **UIウィジェットテスト (`test/widget/category_list_screen_test.dart`)**:
   - カテゴリ追加モーダルでの名称入力・アイコン選択・カラー選択の連動検証
   - 重複名入力時にバリデーションエラーが表示され保存不可となること
