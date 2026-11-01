# ドキュメント案内

- **バージョン**: v0.3.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

iris 支出管理の全9機能について、要求・設計・画面仕様・検証計画を管理する。対象範囲は[ADR-0001](adr/0001-nine-feature-scope.md)を参照する。文書のdoneはレビュー完了を表し、アプリの実装・検証完了を意味しない。

| 読む目的 | 正本・参照先 |
| :--- | :--- |
| 運用・進行・レビュー | [運用インデックス](operations/OPERATIONS.md) |
| 要求・責務・受け入れ基準 | [Layer 1 REQ](req/REQ.md) |
| 振る舞い・共通スキーマ・構成 | [Layer 2 SPEC](spec/SPEC.md) |
| 画面とコンポーネント仕様 | [screens.drawio](spec/screens.drawio)（SCR-001〜008） |
| ケース・合否基準・実施結果の入口 | [Layer 3 VERIFY](verification/VERIFY.md) |
| 対象範囲などの横断判断 | [ADR一覧](adr/ADR.md) |
| レビュー結果とコードの未対応箇所 | [STATUS](STATUS.md) |

参照優先順位は運用 → REQ → SPEC → VERIFY。実装は設計に追従させる。レガシー資料と互換案内は削除済み。以前の版が必要な場合はGit履歴（`9f30200`）を参照する。

日次・履歴は暦日/暦月、予算は開始日基準の家計期間。削除は即時ローカル削除とDB outbox、クラウドはtombstone。UI閾値は600/840。詳細条件の重複定義は避け、各機能の正本を参照する。

過去の無料枠・料金試算・実装済み表記を現行の確定条件や検証合格として扱わない。関連Issueは[支出管理機能を追加する #1](https://github.com/tombee-studio/self-management-app/issues/1)。
