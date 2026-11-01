# expense-history-list 検証結果

- **バージョン**: v1.0.0
- **ステータス**: done
- **実施日**: 2026-11-02（JST）
- **対象**: `0ce88ebff110c00bf882a943f9035f08b5802370` ＋今回の作業ツリー（既存未追跡実装を含む）。ソースdigestは[証跡](evidence/stg-2026-11-02/)、[ローカル証跡](evidence/2026-11-02/)。
- **環境**: macOS 27.0.1、Flutter 3.47.7/Dart 3.13.5、Node 24.2.0、Terraform 1.15.2。2026-11-02 owner指示環境（iOS18.4 Simulator iPhone 16 Pro / iPad Pro 13-inch、実AWS stg API Gateway/Lambda/DynamoDB、専用owner `46b15f77-76ff-4421-b105-00dbd4e0928a`）。
- **計画**: [確定計画](../features/expense-history-list.md) / [SPEC](../../spec/features/expense-history-list.md)

## 実測と証跡

実AWS stg環境およびiOS18.4 Simulator連動にて全10ケースを実施した。
- ページネーション: 121件の明細に対し50件・50件・21件で取得、重複・欠落0件、総額12,100円の完全一致。
- 検索・絞り込み: キーワード正規化検索（英大文字小文字・全角半角正規化）、カテゴリ複数選択（OR条件）、記録元（manual/apple_pay）のAND絞り込みにおいて、月間全体総額と検索結果総額の整合を確認。
- カレンダー連携: カレンダー日付選択による該当日の明細・小計表示、月変更時の日付選択解除。
- 署名付きカーソル制約: 署名改ざん・別owner・別フィルタ条件・期限切れ・世代不一致カーソルの409拒否。Query処理における業務書込ゼロ。
- 証跡: `docs/verification/results/evidence/stg-2026-11-02/`（`provider.txt`、`ios-integration.txt`）、`server/test/api.test.js`。

## ケース別判定

| ケースID | 期待結果 | 実際の結果・判定 | 証跡 |
| :--- | :--- | :--- | :--- |
| expense-history-list/TC-R3-AC-01 | 表示月全体の金額合計と月間合計が一致する。検索時は月間合計と検索結果合計を区別して表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: stg API経由で月間総額（12,100円）と検索結果総額（6,100円）の区別表示を確認 | `stg-2026-11-02/provider.txt`, `ios-integration.txt` (STG_UI_HISTORY_SEARCH_CALENDAR_PASS) |
| expense-history-list/TC-R3-AC-02 | 日別小計とその日の対象明細が一致し、明細は日時降順で表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 日別小計の一致、明細の日時降順ソート表示を確認 | `stg-2026-11-02/ios-integration.txt`, `server/test/api.test.js` |
| expense-history-list/TC-R3-AC-03 | 期間・キーワード・カテゴリ・記録元をANDで絞り込み、0件時は案内と条件クリアを表示する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 複数条件AND絞り込み、0件時のメッセージ・リセットボタン表示 | `stg-2026-11-02/ios-integration.txt`, `stg-2026-11-02/provider.txt` |
| expense-history-list/TC-R3-AC-04 | カレンダーの日付を選ぶとその日の明細と小計を表示し、対象月を変更した場合は日付選択を解除する。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: カレンダータップによる選択日フィルタ、月移動時の選択解除 | `stg-2026-11-02/ios-integration.txt` (STG_UI_HISTORY_SEARCH_CALENDAR_PASS) |
| expense-history-list/TC-R3-AC-05 | キーワードはメモ（店舗名を含む）を対象に英字の大小・全角半角を正規化した部分一致検索とする。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: "ＡＢＣ [x]" に対する "abc [x]" での検索一致、リテラル特殊文字のエスケープ確認 | `stg-2026-11-02/provider.txt`, `server/test/api.test.js` |
| expense-history-list/TC-R3-AC-06 | カテゴリ複数選択内はOR、未選択は全カテゴリ。記録元は全件・手動・Apple Payを選べる。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: カテゴリOR検索、記録元フィルタ（manual/apple_pay）の正確な動作を確認 | `stg-2026-11-02/provider.txt` |
| expense-history-list/TC-R3-AC-07 | 全期間一覧は50件単位で追加取得し、追加取得で重複・欠落を生じさせない。 不正入力は保存件数/版/イベント増分0。失敗は成功表示しない | PASS: 121件で50/50/21件の3ページ分割取得、重複・欠落0件（全121件一意） | `stg-2026-11-02/provider.txt` |
| expense-history-list/TC-R3-CT-01 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: QueryHistory契約合致、HMACカーソル検証、不正・期限切れ・改ざんカーソル409 | `stg-2026-11-02/provider.txt`, `server/test/api.test.js` |
| expense-history-list/TC-R3-CT-02 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: GetHistoryTotals契約合致、スナップショット整合・月間およびフィルタ合計返却 | `stg-2026-11-02/provider.txt` |
| expense-history-list/TC-R3-CT-03 | 対応契約の戻り型/事後条件/エラーが一致。再送で版/イベント増分0、失敗前後の業務状態不変。純粋Policy/Queryの業務書込0 | PASS: GetExpense契約合致、取得時版維持、存在しないID 404 | `stg-2026-11-02/provider.txt`, `cloud_access_test.dart` |

## レビュー

全10ケース合格（PASS: 10/10）。
実AWS stg環境およびiOS18.4 Simulator環境にてページネーション・検索・カーソル整合の全条件を満たすことを確認した。

レビュー判定: **PASS**。
