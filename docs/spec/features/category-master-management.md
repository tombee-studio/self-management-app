# カテゴリマスター管理 設計

- **バージョン**: v0.4.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/category-master-management.md)。設計の正本は本書。

## SPEC-01: マスター操作

SCR-007。表示順一覧、追加・編集シート、アイコンと色のプレビュー、並び替え、削除確認を提供する。名称はtrim後1〜20 grapheme、NFKC正規化後の同名を拒否する。名称重複の正規化値`nameKey`を保存する。アイコンは既存テーマの許可キー、色は`#RRGGBB`のパレットから選ぶ。

未分類`cat_uncategorized`は名称・アイコン・色・削除を不可とし、画面とRepository双方で保護する。新規はUUIDと末尾のsortOrderを割り当てる。並べ替えは全件のsortOrderを0から振り直して一括保存する。初回シードは現行DBの9カテゴリを各固定IDで作り、再起動では重複生成しない。

削除前に紐づく明細件数を示す。承認時は同一トランザクションで対象明細を未分類に更新・updatedAtを更新、CategoryBudgetsを削除、カテゴリを削除し、各変更のoutboxを記録する。支出金額・日時・IDは変えない。キャンセル・DB失敗は全体を維持する。

## SPEC-02: 構成・永続化

`CategoryListScreen`/`CategoryEditSheet` → `CategoryController` → `CategoryRepository`。DBのCategories、Expenses、CategoryBudgets、SyncOutboxを使用する。ID参照の整合性と未分類保護をRepository内のトランザクションで保証する。Cloudからの削除適用でも同じ保護・付け替えルールを使用し、明細から参照されるカテゴリを単純に消さない。

名称の一意性はnameKeyのユニーク制約で保証する。既存DB移行時に正規化名が重複する場合はID順の後続へ` (2)`等の接尾辞を付け20文字以内に収める。候補名が既存nameKeyと重複する間は番号を進め、grapheme境界で元名称を短縮する。ユーザーの明細・カテゴリIDは維持する。

## SPEC-03: エラー・理由

表示中に他端末の変更が来た場合、保存時に最新版を検証する。削除済みカテゴリの編集は保存せず一覧を更新する。システムカテゴリの復元は初期化・移行の冪等処理で行う。画面のボタン非活性だけに依存せず、DB操作入口でも検証することで同期・直接呼び出しでも同じ整合性を維持する。

## REQ対応・検証入口

- [category-master-management/AC-01](../../req/features/category-master-management.md#ac-01): 本書のSPEC-01〜03で具体化。
- [category-master-management/AC-02](../../req/features/category-master-management.md#ac-02): 本書のSPEC-01〜03で具体化。
- [category-master-management/AC-03](../../req/features/category-master-management.md#ac-03): 本書のSPEC-01〜03で具体化。
- [category-master-management/AC-04](../../req/features/category-master-management.md#ac-04): 本書のSPEC-01〜03で具体化。
- [category-master-management/AC-05](../../req/features/category-master-management.md#ac-05): 本書のSPEC-01〜03で具体化。
- [category-master-management/AC-06](../../req/features/category-master-management.md#ac-06): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。
