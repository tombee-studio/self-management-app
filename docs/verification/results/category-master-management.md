# category-master-management 検証結果

- **バージョン**: v1.0.0
- **ステータス**: done
- **実施日**: 2026-11-02（JST）
- **対象**: `0ce88ebff110c00bf882a943f9035f08b5802370` ＋今回の作業ツリー（既存未追跡実装を含む）。ソースdigestは[証跡](evidence/stg-2026-11-02/)、[ローカル証跡](evidence/2026-11-02/)。
- **環境**: macOS 27.0.1、Flutter 3.47.7/Dart 3.13.5、Node 24.2.0、Terraform 1.15.2。2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg API Gateway/Lambda/DynamoDB、専用owner `46b15f77-76ff-4421-b105-00dbd4e0928a`）。
- **計画**: [確定計画](../features/category-master-management.md) / [SPEC](../../spec/features/category-master-management.md)

## 実測と証跡

実AWS stg環境およびiOS18.4 Simulator連動にて全10ケースを実施した。
- 初期カタログ生成: EnsureDefaultCatalogにより食費・日用品・交通費等9カテゴリ生成、初期未設定時404。
- バリデーション・正規化: 名称の全角半角正規化（"ＡＢＣ"と"abc"の重複排除・400拒否）、未分類（cat_uncategorized）の保護（RetireCategory 400拒否）。
- 並び替え: ReorderCatalogによる表示順序・支出入力への即時反映。
- カテゴリ廃止（Retirement）: 1,000件の支出を持つカテゴリの廃止と新規支出登録の並行実行時、未分類への一括動的解決、予算配分削除、総額（100,000円）不変、明細行物理書き換え0件。
- 容量ガード: カタログサイズ150KiB超過時の413拒否・状態不変性確認。
- 証跡: `docs/verification/results/evidence/stg-2026-11-02/`（`provider.txt`、`boundaries.txt`、`ios-integration.txt`）、`server/test/api.test.js`。

## ケース別判定

| ケースID | 期待結果 | 実際の結果・判定 | 証跡 |
| :--- | :--- | :--- | :--- |
| category-master-management/TC-R3-AC-01 | 有効な名称・アイコン・色を保存し、再起動後に復元する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: stg API経由で新規カテゴリ保存、iOS Simulator冷起動後も名称・色・アイコン保持 | `stg-2026-11-02/ios-integration.txt` (STG_UI_CATEGORY_PASS), `cold-relaunch.json` |
| category-master-management/TC-R3-AC-02 | 並び替えた順序を一覧と支出入力へ反映する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: ReorderCatalogによる順序変更成功、UI・入力画面へ反映 | `stg-2026-11-02/provider.txt` |
| category-master-management/TC-R3-AC-03 | 使用中カテゴリ削除時に紐づく支出を未分類へ移し、未分類は編集・削除できない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: カテゴリ廃止で支出が未分類として解決、未分類（cat_uncategorized）の廃止要求は400拒否 | `stg-2026-11-02/provider.txt`, `boundaries.txt` |
| category-master-management/TC-R3-AC-04 | 名称は前後空白を除いて1〜20文字。空白のみと同名重複を拒否する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 空白文字・空白のみ・"ＡＢＣ"/"abc"重複の400拒否・カタログ版不変 | `stg-2026-11-02/provider.txt`, `boundaries.txt` |
| category-master-management/TC-R3-AC-05 | 移し替え・カテゴリ配分削除・カテゴリ削除が一体で成功または取り消され、支出合計は変わらない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 1000件支出での廃止時、配分削除・未分類化が原子的実行、総額不変・物理書き換え0件 | `stg-2026-11-02/provider.txt` |
| category-master-management/TC-R3-AC-06 | 初回起動で食費・日用品・交通費・カフェ・外食、衣服・美容、医療・健康、趣味・娯楽、住まい・通信・未分類を各1件生成する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: EnsureDefaultCatalogによる初期9件のカテゴリ自動作成を確認 | `stg-2026-11-02/provider.txt` |
| category-master-management/TC-R3-CT-01 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: UpsertCategory契約合致、同一要求再送増分0、150KiB超過413 | `stg-2026-11-02/provider.txt`, `cloud_access_test.dart` |
| category-master-management/TC-R3-CT-02 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: RetireCategory契約合致、movedExpenseCount返却、未分類保護 | `stg-2026-11-02/provider.txt` |
| category-master-management/TC-R3-CT-03 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: ReorderCatalog契約合致、全ID一致検査、順序更新 | `stg-2026-11-02/provider.txt` |
| category-master-management/TC-R3-CT-04 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: EnsureDefaultCatalog契約合致、冪等実行（2回目以降generation不変） | `stg-2026-11-02/provider.txt` |

## レビュー

全10ケース合格（PASS: 10/10）。
実AWS stg環境およびiOS18.4 Simulator連動にて要件・設計・契約すべてを満たすことを確認した。

レビュー判定: **PASS**。
