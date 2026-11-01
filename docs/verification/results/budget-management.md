# budget-management 検証結果

- **バージョン**: v1.0.0
- **ステータス**: done
- **実施日**: 2026-11-02（JST）
- **対象**: `0ce88ebff110c00bf882a943f9035f08b5802370` ＋今回の作業ツリー（既存未追跡実装を含む）。ソースdigestは[証跡](evidence/stg-2026-11-02/)、[ローカル証跡](evidence/2026-11-02/)。
- **環境**: macOS 27.0.1、Flutter 3.47.7/Dart 3.13.5、Node 24.2.0、Terraform 1.15.2。2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg API Gateway/Lambda/DynamoDB、専用owner `46b15f77-76ff-4421-b105-00dbd4e0928a`）。
- **計画**: [確定計画](../features/budget-management.md) / [SPEC](../../spec/features/budget-management.md)

## 実測と証跡

実AWS stg環境およびiOS18.4 Simulator連動にて全10ケースを実施した。
- 予算期間計算: 開始日（例: 25日）に基づく期間計算（10/25〜11/24の31日間）、残り日数（11/1時点で24日）、未来日支出（11/20の1,000円）の適正算入。
- 着地予測ガード: 期間開始後最初の3日間は予測警告を抑制（3日目isProjectedToOverspend=false、4日目=trueを確認）。
- 閾値通知: 80%到達・100%到達判定時のshouldNotify判定、DynamoDB metadataテーブルへのreceipt保存による期間内再通知抑止（2回目の同一月評価が空配列[]を返すことを確認）。
- UI動作: 予算0円入力抑止、バリデーションエラー時の入力値保持、保存成功時の元画面/今日画面への復帰。
- 証跡: `docs/verification/results/evidence/stg-2026-11-02/`（`provider.txt`、`boundaries.txt`、`budget-notifications.json`、`ios-integration.txt`）、`test/widget_test.dart`、`server/test/api.test.js`。

## ケース別判定

| ケースID | 期待結果 | 実際の結果・判定 | 証跡 |
| :--- | :--- | :--- | :--- |
| budget-management/TC-R3-AC-01 | 有効な予算設定を保存し、再起動・再表示後も復元する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: stg API経由で予算設定保存、iOS Simulator冷起動後も設定保持 | `stg-2026-11-02/ios-integration.txt` (STG_UI_BUDGET_PASS), `cold-relaunch.json` |
| budget-management/TC-R3-AC-02 | 開始日〜翌月開始日前日を1期間とし、その期間の実績から残額・日次目安を計算する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 開始日25日での期間計算（31日、残り24日、実績1,000円）の正確性を確認 | `stg-2026-11-02/provider.txt` |
| budget-management/TC-R3-AC-03 | 背景タップ・完了操作でキーボードを閉じ、保存成功後は元画面または今日へ戻る。保存失敗時は遷移しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: キーボード解除、保存成功後の今日画面復帰、失敗時の画面保持 | `test/widget_test.dart` (budget rejects zero, preserves failed input) |
| budget-management/TC-R3-AC-04 | 月間総予算は1〜99,999,999円、開始日は1〜28。カテゴリ別配分は0〜99,999,999円とし、総額超過は警告して保存を許可する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 開始日0/29拒否、予算0円拒否、配分超過時の警告発行・保存許容確認 | `stg-2026-11-02/boundaries.txt`, `provider.txt` |
| budget-management/TC-R3-AC-05 | 残額は予算−期間実績、日次目安はmax(0,floor(残額÷当日を含む残り暦日数))とする。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 残額および日次目安計算の整合性・端数切り捨て確認 | `stg-2026-11-02/provider.txt`, `server/test/api.test.js` |
| budget-management/TC-R3-AC-06 | 着地予測はfloor(期間実績÷当日を含む経過暦日数×期間総暦日数)。最初の3日間は予測警告を表示しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 3日目警告抑止（false）、4日目警告点灯（true）を確認 | `stg-2026-11-02/budget-notifications.json` |
| budget-management/TC-R3-AC-07 | 通知有効時に期間内で80%到達・100%到達を各1回通知し、通知拒否時も記録・集計を継続する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 80/100各1回評価、metadata receipt保存により2回目評価は空、通知拒否時も集計継続 | `stg-2026-11-02/budget-notifications.json`, `ipad-integration.txt` |
| budget-management/TC-R3-CT-01 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: ConfigureBudgetPlan契約合致、同一要求再送増分0、CAS制御確認 | `stg-2026-11-02/provider.txt`, `cloud_access_test.dart` |
| budget-management/TC-R3-CT-02 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: GetBudgetPlan契約合致、未設定時404返却、取得時版維持 | `stg-2026-11-02/provider.txt` |
| budget-management/TC-R3-CT-03 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: EvaluateBudgetThresholds契約合致、receipt保存による重複抑止 | `stg-2026-11-02/budget-notifications.json`, `provider.txt` |

## レビュー

全10ケース合格（PASS: 10/10）。
実AWS stg環境およびiOS18.4 Simulator環境にて予算計画・期間計算・閾値通知の全条件を満たすことを確認した。

レビュー判定: **PASS**。
