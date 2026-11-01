# payment-event-ingestion 検証結果

- **バージョン**: v1.0.0
- **ステータス**: done
- **実施日**: 2026-11-02（JST）
- **対象**: `0ce88ebff110c00bf882a943f9035f08b5802370` ＋今回の作業ツリー（既存未追跡実装を含む）。ソースdigestは[証跡](evidence/stg-2026-11-02/)、[ローカル証跡](evidence/2026-11-02/)。
- **環境**: macOS 27.0.1、Flutter 3.47.7/Dart 3.13.5、Node 24.2.0、Terraform 1.15.2。2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg API Gateway/Lambda/DynamoDB、専用owner `46b15f77-76ff-4421-b105-00dbd4e0928a`）。
- **計画**: [確定計画](../features/payment-event-ingestion.md) / [SPEC](../../spec/features/payment-event-ingestion.md)

## 実測と証跡

実AWS stg環境およびiOS18.4 Simulator連動にて全11ケースを実施した。
- 決済取り込み: "¥1,280"等の文字列正規化、整数日本円への変換と保存成功。不正金額（"1+2"）、他通貨（"USD"）、無効日時は400拒否。
- 重複排除: external_tx_id一致時の再送重複判定（duplicate）、同一店舗・金額かつ180秒以内重複判定（duplicate）、181秒超過時の別件取り込み（created）。
- カテゴリ推定: 店舗名キーワード（"セブン"等）によるカテゴリ推定（cat_food）および未設定時の未分類（cat_uncategorized）フォールバック。
- iOSネイティブ連動: カスタムURLスキーム（iris://add-expense?amount=...）からの取り込み、ローカル通知の発行とタップによる編集画面オープン（iPad SimulatorにてSTG_NATIVE_PERMISSION_NOTIFICATION_TAP_PASS、STG_NATIVE_URL_PASS確認）。
- 証跡: `docs/verification/results/evidence/stg-2026-11-02/`（`provider.txt`、`ios-integration.txt`、`ipad-integration.txt`、`ipad-native-ui.txt`）、`server/test/api.test.js`。

## ケース別判定

| ケースID | 期待結果 | 実際の結果・判定 | 証跡 |
| :--- | :--- | :--- | :--- |
| payment-event-ingestion/TC-R3-AC-01 | 有効な決済データを共通形式へ変換し、日本円の整数支出として保存する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: stg API経由で"¥1,280"を1280円として正規化・保存成功、source=apple_pay | `stg-2026-11-02/provider.txt`, `server/test/api.test.js` |
| payment-event-ingestion/TC-R3-AC-02 | 同一外部取引IDの再送を登録せず、IDなしでは記録元・金額・正規化店舗名が一致し決済日時差が3分以内の明細を重複とする。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 外部ID一致でduplicate返却、180秒差以内でduplicate返却、181秒差でcreated返却 | `stg-2026-11-02/provider.txt` |
| payment-event-ingestion/TC-R3-AC-03 | ショートカットAPIによるバックグラウンド記録を次回API取得後に一覧へ反映する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: API/ネイティブURL経由で記録された明細が履歴・一覧へ正常反映 | `stg-2026-11-02/ios-integration.txt` (STG_NATIVE_URL_PASS) |
| payment-event-ingestion/TC-R3-AC-04 | 金額・通貨・日時が不正なイベントは保存せず、失敗を呼び出し元へ返す。金額制約は手動支出と同じ。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 不正金額（"1+2"）、他通貨（"USD"）、無効日時は400拒否・ledger不変 | `stg-2026-11-02/provider.txt` |
| payment-event-ingestion/TC-R3-AC-05 | 店舗名のキーワードでカテゴリを推定し、一致しなければ未分類にする。削除済みカテゴリを参照しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 店舗キーワードによる食費推定、非該当時の未分類割り当てを確認 | `stg-2026-11-02/provider.txt`, `server/test/api.test.js` |
| payment-event-ingestion/TC-R3-AC-06 | ロック中の操作はアプリ前面起動を必要としないAPI経路を使い、通信失敗はショートカット側に通知する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: /paymentエンドポイントによるバックグラウンドPOST/GET正常受容、失敗時HTTPエラー | `stg-2026-11-02/provider.txt` |
| payment-event-ingestion/TC-R3-AC-07 | 取り込み成功・重複・失敗を区別して表示する。アプリ経由の成功時は許可があればローカル通知を発行し、通知タップで該当明細の編集を開く。背景API経路の通知はショートカット側とする。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: iOS Simulatorでの通知許可要求・通知発行・通知タップによる明細オープン完了 | `stg-2026-11-02/ipad-integration.txt` (STG_NATIVE_PERMISSION_NOTIFICATION_TAP_PASS) |
| payment-event-ingestion/TC-R3-CT-01 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: IngestPayment POST契約合致、receiptおよびイベント発行 | `stg-2026-11-02/provider.txt`, `cloud_access_test.dart` |
| payment-event-ingestion/TC-R3-CT-02 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: IngestPayment GET契約合致、クエリパラメータ正規化・処理完了 | `stg-2026-11-02/provider.txt` |
| payment-event-ingestion/TC-R3-CT-03 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: 重複判定Policy純粋性確認、duplicate時増分0 | `server/test/api.test.js`, `stg-2026-11-02/provider.txt` |
| payment-event-ingestion/TC-R3-CT-04 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: カテゴリ推定Policy純粋性確認、未分類フォールバック確認 | `server/test/api.test.js` |

## レビュー

全11ケース合格（PASS: 11/11）。
owner指定のiOS18.4 Simulatorおよび実AWS stg環境にてすべての必須条件を充足した。実Wallet決済・物理ロック画面のハードウェア特性は未測定事項として整理済み。

レビュー判定: **PASS**。
