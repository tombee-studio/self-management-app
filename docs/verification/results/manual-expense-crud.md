# manual-expense-crud 検証結果

- **バージョン**: v1.0.0
- **ステータス**: done
- **実施日**: 2026-11-02（JST）
- **対象**: `0ce88ebff110c00bf882a943f9035f08b5802370` ＋作業ツリー。[ソース・実行証跡](evidence/stg-2026-11-02/)、[ローカル証跡](evidence/2026-11-02/)。
- **環境**: macOS 27.0.1、Flutter 3.47.7/Dart 3.13.5、Node 24.2.0、Terraform 1.15.2。2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg API Gateway/Lambda/DynamoDB、専用owner `46b15f77-76ff-4421-b105-00dbd4e0928a`）。
- **計画**: [確定計画](../features/manual-expense-crud.md) / [SPEC](../../spec/features/manual-expense-crud.md)

## 実測と証跡

実AWS stg環境およびiOS18.4 Simulator（iPhone 16 Pro / iPad Pro 13-inch）連動にて全14ケースを実施した。
- 金額境界: 1円、99,999,999円の登録成功。0円、-1円、100,000,000円、小数の拒否（400）。
- 日付境界: 1970-01-01（Epoch）以降・未来日の保存成功。1969年以前・無効日付の拒否（400）。
- メモ境界: 100 grapheme保存成功、101 grapheme拒否（400）。前後空白除去・改行置換。
- ライフサイクル: 作成・編集・スワイプ削除後のUndo（確定後5秒以内）による同一ID・版復元成功。明示削除（ダイアログ確認）の取り消し非提供。
- UI/端末挙動: 入力変更時の破棄確認、保存失敗時の入力保持・同一要求再送、連続登録時の金額・メモクリアと日付・カテゴリ保持。冷起動（プロセス別プロセスID 62695→62757）後のデータ復元を確認。
- 証跡: `docs/verification/results/evidence/stg-2026-11-02/`（`ios-integration.txt`、`boundaries.txt`、`cold-relaunch.json`、`provider.txt`）、`test/widget_test.dart`、`test/unit/`。

## ケース別判定

| ケースID | 期待結果 | 実際の結果・判定 | 証跡 |
| :--- | :--- | :--- | :--- |
| manual-expense-crud/TC-R3-AC-01 | 有効な入力を1件として保存し、再起動後に同じ内容を参照できる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: stg API経由で登録成功、iOS Simulator冷起動後（PID 62757）も同一支出を参照可能 | `stg-2026-11-02/ios-integration.txt` (STG_UI_CREATE_PASS), `cold-relaunch.json` |
| manual-expense-crud/TC-R3-AC-02 | 編集・削除を一覧と集計へ反映し、削除をキャンセルした場合は明細を保持する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 編集・削除・削除キャンセルが即座に一覧・集計へ反映され、キャンセル時は明細保持 | `stg-2026-11-02/ios-integration.txt` (STG_UI_EDIT_PASS, STG_UI_DELETE_CANCEL_UNDO_PASS) |
| manual-expense-crud/TC-R3-AC-03 | 不正な入力を保存せず、明示削除の確認と保存失敗時の案内を表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 不正値バリデーション拒否、明示削除ダイアログ確認、保存失敗時エラー表示と入力保持 | `test/widget_test.dart`, `stg-2026-11-02/boundaries.txt` |
| manual-expense-crud/TC-R3-AC-04 | 金額は日本円の整数1〜99,999,999円。0・負数・上限超過・不正な計算結果は保存しない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 1円/99,999,999円は受容、0/-1/100,000,000/小数はAPI 400拒否・ledger不変 | `stg-2026-11-02/boundaries.txt`, `provider.txt`, `calculator_parser_test.dart` |
| manual-expense-crud/TC-R3-AC-05 | カテゴリは存在するIDを必須とし、初期選択は未分類。日時は1970-01-01以降で未来日を許可する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 未分類初期選択、存在しないカテゴリ404拒否、1970-01-01以降・未来日受容、1969年以前400拒否 | `stg-2026-11-02/boundaries.txt`, `provider.txt` |
| manual-expense-crud/TC-R3-AC-06 | メモは任意で100文字以内。前後空白を除去し、改行を空白へ置換する。支払い方法は現金・Apple Pay・カード・電子マネー・その他から選ぶ。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 100 grapheme受容、101 grapheme 400拒否、空白トリム・改行空白置換（"STG\n入力"→"STG 入力"） | `stg-2026-11-02/boundaries.txt`, `provider.txt` |
| manual-expense-crud/TC-R3-AC-07 | 連続登録後に金額とメモを空にし、日付・カテゴリ・支払い方法は保持する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 連続登録実行時、金額とメモがクリアされ日付・カテゴリ・支払い方法が保持される | `test/widget_test.dart` (continuous entry clears amount and memo) |
| manual-expense-crud/TC-R3-AC-08 | スワイプ削除はAPI確定後に表示へ反映し、確定応答を受けてから5秒以内の元に戻す操作で元のID・内容を復元する。明示削除には取り消しを付けない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: スワイプ削除後Undoにより元ID・版復元成功、期限超過（31秒）は410拒否、明示削除はUndo非提供 | `stg-2026-11-02/ios-integration.txt`, `provider.txt`, `boundaries.txt` |
| manual-expense-crud/TC-R3-AC-09 | 入力を変更した状態で閉じる場合は破棄確認し、保存失敗時は入力内容を保持する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 入力変更状態で閉じる際に破棄確認ダイアログ表示、保存失敗時に入力値・状態保持 | `test/widget_test.dart` (modal resize preserves amount and dirty close) |
| manual-expense-crud/TC-R3-CT-01 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: RecordExpense契約合致、同requestId再送で同一応答・増分0、異入力409、イベント発行確認 | `stg-2026-11-02/provider.txt`, `test/unit/cloud_access_test.dart` |
| manual-expense-crud/TC-R3-CT-02 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: ModifyExpense契約合致、並列競合時1件のみコミット（200/409）、版CAS確認 | `stg-2026-11-02/provider.txt`, `server/test/api.test.js` |
| manual-expense-crud/TC-R3-CT-03 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: DeleteExpense契約合致、swipe時undoGrant発行、explicit時grant=null、削除後Get 404 | `stg-2026-11-02/provider.txt`, `stg-2026-11-02/boundaries.txt` |
| manual-expense-crud/TC-R3-CT-04 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: RestoreExpense契約合致、同一ID・金額復元、期限切れgrantは410 | `stg-2026-11-02/provider.txt`, `server/test/api.test.js` |
| manual-expense-crud/TC-R3-CT-05 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: CloseExpenseDraft契約合致、dirty判定・破棄確認純粋ロジック書込0 | `test/widget_test.dart`, `server/test/api.test.js` |

## レビュー

全14ケース合格（PASS: 14/14）。
2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg）において全必須条件を満たし、実機固有機能（Android固有、物理Wallet決済）は未測定事項として正しく分離されていることを確認した。

レビュー判定: **PASS**。
