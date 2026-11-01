# 支出の手動登録・編集・削除 設計（既存資料の統合）

- **バージョン**: v0.1.0
- **ステータス**: draft
- **資料区分**: 過去資料（現行仕様・工程ゲートの対象外）
- **整理日**: 2026-11-01（JST）

対応要求: [要求案](../../../req/features/manual-expense-crud.md)。要求がdraftのため、本書は未確定の既存設計資料として保管する。

削除同期・取り消しの関連資料: [クラウド同期](../../../spec/features/aws-cloud-database-sync.md)。未確定の削除方式は[DOC-02](../../../STATUS.md)で管理する。

## 保存時点の移行範囲と確定条件

既存の仕様・詳細設計を同一文書へ移した。以下の保存節は当時の案であり、実装との一致・検証完了を保証しない。重複や矛盾は採用判断をせず保持し、[差分一覧](../../../STATUS.md)へ記録した。REQ確定後に振る舞い・データモデル・状態管理・異常系を同期し、レビューする。

## 保存資料: manual-expense-crud / 仕様

移行元: `docs/spec/features/manual-expense-crud.md`。旧節番号とコード例を保持。

### 支出の手動登録・編集・削除機能 (manual-expense-crud) 仕様書

#### 1. 目的・概要
日常の支出において、Apple Pay 等の外部決済自動検知だけでなく、現金払いや未対応決済の支出をユーザーがその場ですばやく手動登録・編集・削除できるようにする。
素早い入力操作（カスタム電卓テンキー、ワンタップカテゴリ選択、日付クイックチップ）により、記録の摩擦を最小化し、支出の修正や削除も直感的に行えるようにする。

---

#### 2. ユーザーフロー・画面要件

##### 2.1 ユーザーフロー

###### A. 新規支出の登録
1. ユーザーはダッシュボード右下の「＋」ボタン（FAB）、または履歴一覧の追加ボタンをタップする。
2. 画面下部から「支出登録モーダル（Bottom Sheet）」がスライドアップして表示される（タブレット横画面時は中央ダイアログ）。
3. 電卓テンキーを使って金額を入力する（必要に応じて `+`, `-`, `×`, `÷` の計算を行う）。
4. カテゴリ一覧から該当カテゴリを1タップで選択する。
5. 日付（デフォルトは選択中の日/本日）、支払い方法（現金/Apple Pay/カード等）、メモ（店舗名等）を必要に応じて指定する。
6. 「保存する」をタップすると、ローカルDBに保存されモーダルが閉じる（「続けて入力」をタップした場合は入力欄がリセットされ、連続して次の支出を登録できる）。
7. ダッシュボードや履歴一覧の合計金額・進捗バーが即座に自動更新される。

###### B. 登録済み支出の編集
1. 日次ダッシュボードまたは支出履歴一覧で、任意の明細カードをタップする。
2. 既存データが入力された状態で「支出編集モーダル」が開く。
3. 金額、カテゴリ、日付、支払い方法、メモを修正し、「更新する」をタップするとローカルDBが更新される。

###### C. 支出の削除
- **方法1（編集モーダル経由）**: 編集モーダル右上の「ゴミ箱」アイコンをタップし、確認ダイアログ（「この支出を削除しますか？」）で「削除」を選択する。
- **方法2（リストスワイプ経由）**: 明細リストの項目を右から左へスワイプ（Dismissible）すると削除される。スワイプ直後に画面下部へ「支出を削除しました [元に戻す]」のスナックバーが5秒間表示され、タップで取り消しが可能。

##### 2.2 画面コンポーネント要件
- **画面構成および画面仕様 (draw.io)**: [docs/spec/screens.drawio](../../../spec/screens.drawio) （タブ: `支出登録・編集モーダル` / SCR-005）
- **ヘッダーエリア**:
  - タイトル（新規時:「支出を記録」、編集時:「支出を編集」）
  - 閉じるボタン（`✕`）
  - 削除ボタン（ゴミ箱アイコン、編集時のみ表示）
- **金額ディスプレイ (Amount Display)**:
  - 大きな金額表示（例: `¥1,280`）。未入力時はプレースホルダ `¥0`。
  - 計算式入力中は計算途中式（例: `800 + 480`）を上部に小さく表示。
- **カテゴリセレクタ (Category Selector)**:
  - 横スクロールチップまたは 2〜3行のグリッド表示。
  - アイコン＋カテゴリ名（食費、日用品、交通費、交際費、趣味、衣服、医療、教育、その他）。
  - 選択中のカテゴリはアクセントカラー背景＋拡大アニメーションで強調。
- **補助入力エリア (Meta Inputs)**:
  - **日付ピッカー**: クイック選択チップ（「今日」「昨日」「日付選択」）。日付選択タップで標準カレンダー表示。
  - **支払い方法セレクタ**: ドロップダウンまたは水平チップ（「現金」「Apple Pay」「クレジットカード」「電子マネー」「その他」）。
  - **メモ / 店舗名**: 1行テキスト入力（例:「セブンイレブンでおにぎり」）。過去履歴からの候補補完（サジェスト）。
- **カスタム電卓テンキー (Calculator Keypad)**:
  - 数字キー: `0` 〜 `9`, `00`
  - 四則演算キー: `+`, `-`, `×`, `÷`, `=`
  - 削除・クリアキー: `C`（クリア）、`⌫`（1文字バックスペース）
- **フッターアクション**:
  - 新規時: 「保存する」（メインボタン）＋「続けて入力」（サブボタン）
  - 編集時: 「更新する」（メインボタン）

---

#### 3. 入力項目・バリデーション

| 項目名 | 必須 | 形式 / 制約 | 初期値 | エラー条件・挙動 |
| :--- | :---: | :--- | :--- | :--- |
| **金額 (Amount)** | ○ | 整数（四則演算結果）<br>範囲: `1` 〜 `99,999,999` 円 | `0` (未入力) | 0円または未入力時は「保存」ボタン非活性。99,999,999円超過時は入力抑止。 |
| **カテゴリ (Category)** | ○ | カテゴリマスタID | 前回選択カテゴリまたは「未分類/その他」 | 未選択状態は許容しない（必ずいずれかが選択される）。 |
| **日付・時刻 (SpentAt)** | ○ | 日時形式 (`DateTime`) | 現在日時、またはダッシュボード表示日 | 未来日時は警告なしで許容（事前予定入力対応）。1970年以前は無効。 |
| **支払い方法 (Method)** | ○ | Enum: `cash`, `applePay`, `creditCard`, `eMoney`, `other` | `cash` (現金) | 不正な値は `other` にフォールバック。 |
| **メモ / 店舗名 (Memo)** | 任意 | 文字列 (最大100文字) | 空文字 | 100文字超過時は追加入力不可。改行は単一スペースに置換。 |

---

#### 4. ビジネスロジック・計算ルール

##### 4.1 電卓テンキーの計算ロジック
1. **入力バッファ管理**:
   - 入力文字列（例: `"1200+300*2"`）を管理し、四則演算の優先順位（乗除先行）を考慮して評価する。
   - 連続する演算子入力（例: `++`, `+-`）は最後の演算子で上書きする。
   - `0` の連続入力（空状態での `00` や `000`）は無視し、先頭の冗長な `0` を防ぐ。
2. **評価（イコール `=` / 保存時）**:
   - 途中に演算子が残った状態で「保存する」が押された場合、自動的に末尾の演算子を無視または計算を完了させてから保存する（例: `"1000+"` で保存 → `1000` 円として処理）。
   - ゼロ除算（`÷ 0`）が行われた場合は「エラー」と表示し、金額をリセットする。

##### 4.2 保存・更新時のデータ同期ロジック
1. **ローカルDB (drift) トランザクション**:
   - `expenses` テーブルへのレコード追加（`insert`）または更新（`update`）。
   - 手動入力レコードの場合、`source` カラムには `'manual'` を設定し、`external_tx_id` は `NULL` とする。
2. **リアクティブ再計算**:
   - 保存完了通知を Riverpod Provider 経由で発行。
   - 開いているダッシュボードの日次合計、カテゴリ割合、進捗率、および履歴一覧の該当月の合計が 0ミリ秒遅延で即時再レンダリングされる。

##### 4.3 スワイプ削除と取り消し (Undo) ロジック
1. リスト上でスワイプされた際、即座に画面上から明細行をフェードアウトさせる（仮削除状態）。
2. 下部にスナックバーを表示: `「支出明細を削除しました」 [元に戻す]` （表示時間: 5秒）。
3. **元に戻す（Undo）タップ時**:
   - DB削除を取り消し、元のインデックス位置にアイテムを復元してアニメーション表示。
4. **スナックバー終了時（または別画面遷移時）**:
   - drift の `delete(expenses)` を実行し、完全削除をコミットする。

---

#### 5. エラーハンドリング・エッジケース

1. **未保存のままモーダルを閉じようとした場合**:
   - 金額が 1円以上入力されている状態で画面外タップや `✕` ボタンが押された場合、確認シート（「入力途中の内容を破棄しますか？ [破棄する] [入力を続ける]」）を表示して誤操作による入力内容消失を防止する。
2. **連続入力モード時の日付保持**:
   - 「続けて入力」を押下した際、**日付と支払い方法は直前の値を保持**し、金額とメモのみをクリアする（複数枚のレシートを同じ日付で一括登録するユーザーの入力負荷を軽減）。
3. **電卓のオーバーフロー / 小数点**:
   - 日本円（JPY）モードでは小数点は無効化（キーパッドから除外または非活性）。
   - 計算結果が 99,999,999 円を超えた場合は「上限を超えています」とトースト警告を表示し、直前の有効な値に戻す。

## 保存資料: manual-expense-crud / 詳細設計

移行元: `docs/implementation/features/manual-expense-crud.md`。旧節番号とコード例を保持。

### 支出の手動登録・編集・削除機能 (manual-expense-crud) 詳細設計書

#### 1. 概要・アーキテクチャ構成
本機能は、ユーザーが日常の支出を手動ですばやく登録・編集・削除するためのUIおよびビジネスロジック、データ永続化を提供します。
Flutterのリアクティブな状態管理（Riverpod）と、完全ローカルDB（drift / SQLite）を組み合わせ、オフライン環境下で極めて高速（タップから描画まで16ms以内）に応答する設計とします。

---

#### 2. コンポーネント構成・UIツリー

```
lib/features/expenses/
├── domain/
│   ├── models/
│   │   ├── expense_form_state.dart     # 入力フォーム状態モデル (Freezed)
│   │   └── calculator_token.dart       # 電卓トークン定義
│   └── services/
│       └── calculator_parser.dart      # 四則演算パース・評価エンジン
├── data/
│   └── repositories/
│       └── expense_repository.dart     # drift DB CRUD操作実装
└── presentation/
    ├── controllers/
    │   └── expense_form_controller.dart# 入力・編集状態管理 (StateNotifier)
    └── widgets/
        ├── expense_form_modal.dart     # モーダル本体（ボトムシート/ダイアログ）
        ├── amount_display.dart         # 金額＆計算式表示部
        ├── category_selector.dart      # カテゴリ選択チップ・グリッド
        ├── expense_meta_inputs.dart    # 日付ピッカー・支払方法・メモ入力
        └── calculator_keypad.dart      # 4×4電卓テンキー
```

##### 2.1 画面表示アダプティブ設計
- **スマートフォン（Compact Width < 600dp）**:
  - `showModalBottomSheet` を使用し、画面下部からスライドアップ。
  - セーフエリアを考慮した高さ自動調整。
- **タブレット（Medium / Expanded Width ≥ 600dp）**:
  - `showDialog` を使用し、画面中央に幅 460dp・角丸 16dp のダイアログとして配置。
  - 画面の向き（縦横）に関わらず最適な中央フォーカスを実現。

---

#### 3. データモデル・テーブル定義

##### 3.1 フォーム状態モデル (`ExpenseFormState`)
```dart
@freezed
class ExpenseFormState with _$ExpenseFormState {
  const factory ExpenseFormState({
    required int amount,                   // 現在の計算済み金額（円）
    required String formulaDisplay,        // 入力中の計算式（例: "800+480"）
    required String? selectedCategoryId,  // 選択されたカテゴリID
    required DateTime spentAt,             // 支出日時
    required PaymentMethod paymentMethod,  // 支払い方法 (cash, applePay, creditCard, eMoney, other)
    required String memo,                  // メモ / 店舗名 (最大100文字)
    required bool isEditing,               // 新規作成か編集か
    required String? editingExpenseId,     // 編集対象の支出ID (新規は null)
    required bool isValid,                 // 保存可能か (amount > 0 && selectedCategoryId != null)
    required bool isContinuous,            // 「続けて入力」モードフラグ
  }) = _ExpenseFormState;
}
```

##### 3.2 データベース永続化 (`drift` テーブル定義)
手動登録データは既存の `expenses` テーブルに以下の通りマッピングされます。
```dart
class Expenses extends Table {
  TextColumn get id => text()();                               // UUID v4
  IntColumn get amount => integer()();                         // 金額（JPY整数）
  TextColumn get categoryId => text().references(Categories, #id)(); // 外部キー
  DateTimeColumn get spentAt => dateTime()();                  // 支出発生日時
  TextColumn get memo => text().nullable()();                  // 店舗名/メモ
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get source => text().withDefault(const Constant('manual'))(); // 'manual' または 'external_event'
  TextColumn get externalTxId => text().nullable()();          // 手動登録は常に NULL
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

#### 4. ロジック・状態管理設計

##### 4.1 四則演算パース・評価ロジック (`CalculatorParser`)
電卓テンキーからの入力をリアルタイムで安全に評価します。

```dart
class CalculatorParser {
  /// 入力文字列を評価して整数（JPY）を返す。
  /// 例: "800+480*2" -> 1760
  static int evaluate(String input) {
    if (input.isEmpty) return 0;

    // 末尾が演算子で終わっている場合は末尾を除去して安全に評価
    final sanitized = _sanitizeTrailingOperators(input);
    if (sanitized.isEmpty) return 0;

    try {
      // 四則演算トークナイズと操車場アルゴリズム (Shunting-yard) で逆ポーランド記法 (RPN) に変換
      final rpn = _toReversePolishNotation(sanitized);
      final result = _evaluateRPN(rpn);
      return result.clamp(0, 99999999);
    } catch (_) {
      return 0;
    }
  }
}
```
- **ゼロ除算抑止**: `÷ 0` の場合は例外をスローせず直前の値を維持、またはエラー表示。
- **触覚フィードバック**: キータップ時に `HapticFeedback.lightImpact()` を発火。

##### 4.2 フォームコントローラ (`ExpenseFormController`)
```dart
class ExpenseFormController extends AutoDisposeStateNotifier<ExpenseFormState> {
  final ExpenseRepository _repository;

  ExpenseFormController(this._repository, {Expense? initialExpense})
      : super(_initialState(initialExpense));

  void onKeyTapped(String key) { ... }       // 数字・演算子・クリアの処理
  void onCategorySelected(String catId) { ... }
  void onDateChanged(DateTime date) { ... }
  void onPaymentMethodChanged(PaymentMethod method) { ... }
  void onMemoChanged(String memo) { ... }

  Future<bool> save() async {
    if (!state.isValid) return false;
    if (state.isEditing) {
      await _repository.updateExpense(state.toUpdateCompanion());
    } else {
      await _repository.createExpense(state.toInsertCompanion());
    }
    return true;
  }

  Future<void> delete() async {
    if (state.editingExpenseId != null) {
      await _repository.deleteExpense(state.editingExpenseId!);
    }
  }
}
```

---

#### 5. スワイプ削除と取り消し (Undo) 設計

一覧画面（ダッシュボード・履歴）での明細スワイプ削除時:
1. `Dismissible` ウィジェットを使用:
   - スワイプ方向: `DismissDirection.endToStart`（右から左）。
   - 背景（`background`）: 赤色背景（`#EF4444`）＋ゴミ箱アイコン（`Icons.delete`）。
2. `onDismissed` コールバック:
   - メモリ上のローカルリストから即時除外して高速なUI消去を実現。
   - `ScaffoldMessenger.showSnackBar` をトリガー:
     ```dart
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('支出明細を削除しました'),
         duration: const Duration(seconds: 5),
         action: SnackBarAction(
           label: '元に戻す',
           onPressed: () {
             // アイテムをリストに復元し、DB削除をキャンセル
             ref.read(expenseListControllerProvider.notifier).undoDelete(item);
           },
         ),
       ),
     ).closed.then((reason) {
       // Undo されずに SnackBar が閉じた場合のみ、実際に drift DB から物理削除を実行
       if (reason != SnackBarClosedReason.action) {
         ref.read(expenseRepositoryProvider).deleteExpense(item.id);
       }
     });
     ```

---

#### 6. テスト計画

1. **電卓パーサー単体テスト (`test/unit/calculator_parser_test.dart`)**:
   - 加減乗除の優先順位計算テスト（`100 + 200 * 3 == 700`）
   - 連続演算子入力の上書きテスト（`100 + - * 50 == 5000`）
   - ゼロ除算時の安全性テスト（`1000 / 0 == 0` または例外なし）
   - 最大桁数上限（99,999,999）クリッピングテスト
2. **状態管理単体テスト (`test/unit/expense_form_controller_test.dart`)**:
   - 初期値ロード（新規モード vs 編集モード）
   - バリデーション状態の切り替え（金額0円時は `isValid: false`）
   - 「続けて入力」押下時に日付・支払い方法が保持されることの確認
3. **ウィジェットテスト (`test/widget/expense_form_modal_test.dart`)**:
   - テンキーをタップして金額ディスプレイが更新されること
   - カテゴリをタップして選択状態が切り替わること
   - 保存ボタンタップ時にコントローラの `save()` が呼ばれること
