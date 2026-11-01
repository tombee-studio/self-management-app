# カテゴリマスター管理 設計

- **バージョン**: v1.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/category-master-management.md)。設計の正本は本書。

## ドメイン境界・モデル

分類: **CategoryCatalogの更新モデル**。[共通アーキテクチャ](../architecture.md)と[ADR-0002](../../adr/0002-domain-contract-design.md)に従う。全契約はv1.0.0。既存REQの業務範囲・AC番号を維持する。

| モデル | 所有・構成・制約 |
| :--- | :--- |
| CategoryCatalog（集約ルート） | OwnerId、Category集合、名称索引、並び順、AggregateVersion |
| Category（集約内エンティティ） | CategoryId、CategoryName、IconKey、ColorHex、isSystem。単体でCatalog外から保存しない |

### 不変条件・依存方向

- NFKC・lowercaseで正規化した同名キーが重複せず、有効カテゴリIDと連続順序を保持する。
- cat_uncategorizedは常に存在し編集・削除不可。初期9件は冪等生成する。
- カテゴリ廃止は支出移行・配分削除まで完了してから成功とする。

CategoryCatalogRepository.load/save（catalogVersionのCAS）、CategoryLookup、LedgerReclassificationPort、BudgetAllocationPort、UnitOfWork。RetireCategoryCoordinatorが異なるコンテキストのPortを同一ローカルUoWへ参加させる。

### 公開契約

契約の成功・失敗・版・トランザクション・再試行の共通意味は[共通規則](../architecture.md#5-契約の共通規則)。Operationの引数型は上の値型/DTOとSPEC-01の項目定義を使い、DB行型を公開しない。QueryのsnapshotIdとVersionは互換ではない。

<a id="cat-c01"></a>
#### CAT-C01: UpsertCategory

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `UpsertCategory{categoryId,expectedCatalogVersion,name,iconKey,colorHex} → Result<CatalogView>` |
| 事前条件 | 名前・許可アイコン・色が有効、同名なし、対象はシステム予約IDでない、版一致 |
| 成功後の保証・変更範囲 | 追加/変更・Catalog版・CatalogChanged/Outboxを一体保存。追加順は末尾 |
| 失敗 | ValidationFailed/InvariantViolation/VersionConflict/StorageFailure |
| 冪等性・再試行 | 同ID同値はAlreadyApplied。IDの異なる同名は失敗 |
| 対応REQ | [AC-01](../../req/features/category-master-management.md#ac-01), [AC-04](../../req/features/category-master-management.md#ac-04) |

<a id="cat-c02"></a>
#### CAT-C02: ReorderCatalog

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ReorderCatalog{expectedCatalogVersion,orderedIds} → Result<CatalogView>` |
| 事前条件 | 現行の全IDが重複なく1回ずつ含まれ、版一致 |
| 成功後の保証・変更範囲 | 連続sortOrderと新Catalog版を一体保存。支出入力へ同じ順序を射影 |
| 失敗 | ValidationFailed/VersionConflict/StorageFailure |
| 冪等性・再試行 | 同じ並びならAlreadyApplied |
| 対応REQ | [AC-02](../../req/features/category-master-management.md#ac-02) |

<a id="cat-c03"></a>
#### CAT-C03: RetireCategory

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `RetireCategory{categoryId,expectedCatalogVersion} → Result<RetirementView{movedExpenseCount}>` |
| 事前条件 | 対象が存在し未分類でない。版一致 |
| 成功後の保証・変更範囲 | 同UoWで全対象Expenseのカテゴリ参照を未分類へ変更し各版/Outbox更新、Budget配分削除と版更新、Catalogから除去。支出金額/ID/日時を保持 |
| 失敗 | InvariantViolation/NotFound/VersionConflict/StorageFailure |
| 冪等性・再試行 | 廃止済みはAlreadyRetired、二重移行や追加削除イベントなし |
| 対応REQ | [AC-03](../../req/features/category-master-management.md#ac-03), [AC-05](../../req/features/category-master-management.md#ac-05) |

<a id="cat-c04"></a>
#### CAT-C04: EnsureDefaultCatalog

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `EnsureDefaultCatalog{ownerId} → Result<CatalogView>` |
| 事前条件 | 空Catalogまたは既存Catalogを識別できる |
| 成功後の保証・変更範囲 | 初回のみ標準9件作成。既存のユーザー変更・IDは上書きしない |
| 失敗 | StorageFailure |
| 冪等性・再試行 | 再起動・移行で重複生成しない |
| 対応REQ | [AC-06](../../req/features/category-master-management.md#ac-06) |

## SPEC-01: マスター操作

SCR-007。表示順一覧、追加・編集シート、アイコンと色のプレビュー、並び替え、削除確認を提供する。名称はtrim後1〜20 grapheme、NFKC・lowercase正規化後の同名を拒否する。名称重複の正規化値`nameKey`を保存する。アイコンは既存テーマの許可キー、色は`#RRGGBB`のパレットから選ぶ。

未分類`cat_uncategorized`は名称・アイコン・色・削除を不可とし、画面とRepository双方で保護する。新規はUUIDと末尾のsortOrderを割り当てる。並べ替えは全件のsortOrderを0から振り直して一括保存する。初回シードは現行DBの9カテゴリを各固定IDで作り、再起動では重複生成しない。

削除前に紐づく明細件数を示す。承認時は同一トランザクションで対象明細を未分類に更新・updatedAtを更新、CategoryBudgetsを削除、カテゴリを削除し、各変更のoutboxを記録する。支出金額・日時・IDは変えない。キャンセル・DB失敗は全体を維持する。

## SPEC-02: 構成・永続化

CategoryListScreen/CategoryEditSheet → CatalogCommandHandler/RetireCategoryCoordinator → CategoryCatalogRepositoryと台帳/予算Port → 同一ローカルUoW。具象DBによる他コンテキスト直接更新をUIから呼ばない。

以下はPortのInfrastructure実装と計算/表示Policyの具体化。具象DB・通知SDKをDomainへ持ち込まない。複数の物理テーブルに分かれていても、上の集約境界と契約単位で保存する。


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

## 契約検証・実装への移行

[機能別検証計画](../../verification/features/category-master-management.md)のTC-CTで公開契約ごとの前提違反・成功保証・不変条件・失敗時副作用・再試行を検証する。既存SPEC-01〜03の業務/画面条件を契約の詳細規則として維持する。既存実装と途中の変更は移行元であり、本設計に適合済みとは扱わない。
