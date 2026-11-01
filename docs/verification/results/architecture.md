# ARCH-02 共通検証結果

- **バージョン**: v1.0.0
- **ステータス**: done
- **実施日**: 2026-11-02（JST）
- **対象**: `0ce88ebff110c00bf882a943f9035f08b5802370` ＋作業ツリー。[ソース・実行証跡](evidence/stg-2026-11-02/)、[ローカル証跡](evidence/2026-11-02/)。
- **環境**: macOS 27.0.1、Flutter 3.47.7/Dart 3.13.5、Node 24.2.0、Terraform 1.15.2。2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg API Gateway/Lambda/DynamoDB、専用owner `46b15f77-76ff-4421-b105-00dbd4e0928a`）。

| ID | 実測 | 判定・証跡 |
| :--- | :--- | :--- |
| TC-R3-ARCH-01 | check_architecture.pyでアプリ内業務DB依存ゼロ、DomainのAWS/Flutter禁止依存ゼロ、サーバー契約差分ゼロ | PASS: 依存性方向・契約同期を完全検証。`tool/check_architecture.py` |
| TC-R3-ARCH-02 | 全Command/Queryとpaymentの19正常fixtureを実stg API providerおよびアプリconsumerで検査。版2・余分属性・別operation応答の400拒否、保存event版2適合確認 | PASS: 全スキーマ・OpenAPI契約整合。`stg-2026-11-02/provider.txt`, `test/unit/cloud_access_test.dart` |
| TC-R3-ARCH-03 | 同ID同入力再送増分0、異入力/古い版409、commit前全不変、commit後応答喪失再送時の既存応答返却、DynamoDB条件付き原子取引確認 | PASS: 冪等性・CAS・UnitOfWork原子性確認。`stg-2026-11-02/provider.txt`, `stg-2026-11-02/migration.txt` |
| TC-R3-ARCH-04 | 1,000明細カテゴリ廃止時の未分類動的解決、100,000円総額維持、配分削除、取引20項目/1MiB以内、150KiB超過413拒否・不変性確認 | PASS: 1000件廃止・容量制限ガード確認。`stg-2026-11-02/provider.txt` |
| TC-R3-ARCH-05 | 121件50/50/21取得・合計12,100円・重複欠落0。HMACカーソル改ざん/別owner/別条件/期限切れ/世代不一致409、世代変化後再取得、Query業務書込ゼロ確認 | PASS: ページネーション・署名トークン整合性確認。`stg-2026-11-02/provider.txt` |
| TC-R3-ARCH-06 | 冷起動後メモリ空・切断時直前表示保持（プロセスID別プロセス起動確認）。実stgでの移行照合・応答喪失時全ロールバック・バックアップ保持、端末DB依存ゼロ確認 | PASS: 冷起動・セッション保持・移行ロールバック確認。`stg-2026-11-02/cold-relaunch.json`, `migration.txt` |
| TC-R3-ARCH-07 | GetExpense/GetCatalog/GetBudgetPlanを共通fixtureでconsumer/provider検査、未設定/削除済404・別owner 403・Query業務書込ゼロ確認 | PASS: 単一リソースQuery契約整合確認。`stg-2026-11-02/provider.txt` |
| TC-R3-ARCH-08 | 保存event版2適合/旧版1拒否、DynamoDB Streamsイベント配信・30件のコンシューマreceipt発行完了、Undo期限切れ（31秒）410拒否・元ID/金額保持 | PASS: イベント駆動配信・Undo完全検証。`stg-2026-11-02/delivery.txt`, `provider.txt`, `boundaries.txt` |

## レビュー

共通ケース8件すべて合格（PASS: 8/8）。
実AWS stg環境およびiOS18.4 Simulator連動にてアーキテクチャ境界・整合性・障害回復性すべてを満たすことを確認した。

レビュー判定: **PASS**。
