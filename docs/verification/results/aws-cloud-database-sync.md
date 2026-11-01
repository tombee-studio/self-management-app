# aws-cloud-database-sync 検証結果

- **バージョン**: v1.0.0
- **ステータス**: done
- **実施日**: 2026-11-02（JST）
- **対象**: `0ce88ebff110c00bf882a943f9035f08b5802370` ＋今回の作業ツリー（既存未追跡実装を含む）。ソースdigestは[証跡](evidence/stg-2026-11-02/)、[ローカル証跡](evidence/2026-11-02/)。
- **環境**: macOS 27.0.1、Flutter 3.47.7/Dart 3.13.5、Node 24.2.0、Terraform 1.15.2。2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg API Gateway/Lambda/DynamoDB、専用owner `46b15f77-76ff-4421-b105-00dbd4e0928a`）。
- **計画**: [確定計画](../features/aws-cloud-database-sync.md) / [SPEC](../../spec/features/aws-cloud-database-sync.md)

## 実測と証跡

実AWS stg環境およびiOS18.4 Simulator連動にて全12ケースを実施した。
- クラウドデータアクセス: 端末内ローカルDB（SQLite等）への永続依存ゼロ（check_architecture.py PASS）。メモリ内状態と入力の保持、通信失敗時のエラー・再試行確認。
- 冪等性・原子性・CAS: 同一要求ID再送での二重更新防止（増分0・既存応答返却）、並列更新における古い版の409拒否と最新集約版の維持。DynamoDB TransactWriteCommandによる状態・Receipt・世代・イベントの原子的保存。
- 移行・ロールバック: 実AWS stgでの移行検証、コミット後応答喪失シミュレーション時の全行ロールバック・バックアップ保護確認。
- 費用計測・CloudWatch監視: stgでのLambda実行時間、DynamoDB消費RCU/WCUの実測（collect_stg_metrics.py実行確認）。
- 証跡: `docs/verification/results/evidence/stg-2026-11-02/`（`terraform-apply.txt`、`environment.json`、`provider.txt`、`migration.txt`、`runtime-after-fix.json`）、`tool/check_architecture.py`。

## ケース別判定

| ケースID | 期待結果 | 実際の結果・判定 | 証跡 |
| :--- | :--- | :--- | :--- |
| aws-cloud-database-sync/TC-R3-AC-01 | 通信失敗時はエラーと再試行を表示し、入力とセッション内の直前表示を保持する。未取得データのオフライン参照・保存は提供しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 通信失敗時の再試行案内、入力・直前表示保持、端末DB依存ゼロを確認 | `test/widget_test.dart`, `tool/check_architecture.py` |
| aws-cloud-database-sync/TC-R3-AC-02 | 追加・更新・削除はAWS API確定後に成功とし、同じ要求IDの再送で二重更新しない。応答喪失時は結果不明として確認/再送できる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: API確定後のUI反映、同requestId再送で状態・版・イベント増分ゼロ（元応答返却） | `stg-2026-11-02/provider.txt`, `ios-integration.txt` (STG_UI_UNKNOWN_OUTCOME_REPLAY_PASS) |
| aws-cloud-database-sync/TC-R3-AC-03 | 削除済み明細は通常の取得結果に含めず、許可期間内の取り消しで同じID・内容に戻る。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 削除明細のQuery除外、Undo成功時の同一ID・内容復元、期限超過410 | `stg-2026-11-02/provider.txt`, `boundaries.txt` |
| aws-cloud-database-sync/TC-R3-AC-04 | 起動・復帰・明示更新・変更成功後に必要な画面データをAPI取得する。自動同期ON/OFFとPush/Pullは提供しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 起動・復帰時のAPI直接取得、旧同期ルート（/sync/push, /sync/pull）の404削除確認 | `stg-2026-11-02/provider.txt`, `ios-integration.txt` (STG_UI_STARTUP_PASS) |
| aws-cloud-database-sync/TC-R3-AC-05 | 取得/保存中・成功・失敗・結果不明を区別し、失敗で最終成功日時を更新しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 状態遷移（取得中・成功・失敗・結果不明）の個別表示、失敗時のタイムスタンプ非更新 | `test/widget_test.dart`, `stg_app_test.dart` |
| aws-cloud-database-sync/TC-R3-AC-06 | 更新競合はサーバーの集約版で検出し、古い版は拒否して入力を保持し最新版の確認を案内する。端末時計で上書き優先度を決めない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 並列更新時の古い版409拒否、サーバー集約版によるCAS制御・競合案内 | `stg-2026-11-02/provider.txt`, `ios-integration.txt` (STG_UI_STALE_DISPLAY_RETRY_PASS) |
| aws-cloud-database-sync/TC-R3-AC-07 | 支出・カテゴリ・カテゴリ配分・予算をAWSに保存し、カテゴリ廃止時の未分類化と配分削除が一体で可視化され、支出合計が変わらない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 1000件廃止時の一括未分類化、配分削除、支出合計不変（物理書き換え0件） | `stg-2026-11-02/provider.txt` |
| aws-cloud-database-sync/TC-R3-AC-08 | 月額500円を運用目標とし、費用通知と計測条件を構成へ記録する。通知は課金停止や上限保証を意味しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: Terraform構成での費用監視設計、stg CloudWatchメトリクス収集・集計完了 | `stg-2026-11-02/runtime-after-fix.json`, `tool/collect_stg_metrics.py` |
| aws-cloud-database-sync/TC-R3-CT-06 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: HealthResponse/schemaVersion契約合致、旧同期ルート404 | `stg-2026-11-02/provider.txt` |
| aws-cloud-database-sync/TC-R3-CT-08 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: DynamoDB UnitOfWorkによる原子取引（全成功または全不変） | `stg-2026-11-02/provider.txt`, `server/test/dynamodb.test.js` |
| aws-cloud-database-sync/TC-R3-CT-09 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: 移行インポート・ロールバック契約合致、障害注入時の全不変性確認 | `stg-2026-11-02/migration.txt`, `server/test/migration.test.js` |
| aws-cloud-database-sync/TC-R3-CT-10 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: DynamoDB Streamsイベント配信・receipt契約合致（30件連続配信完了） | `stg-2026-11-02/delivery.txt`, `provider.txt` |

## レビュー

全12ケース合格（PASS: 12/12）。
実AWS stg環境へのTerraformデプロイ、実DynamoDBテーブル群へのアクセス、ストリーム配信、移行ロールバック、およびiOS SimulatorとのAPI連動を確認した。月額課金実請求の完了は目標値管理として分離されている。

レビュー判定: **PASS**。
