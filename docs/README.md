# ドキュメント案内

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

iris 支出管理の全9機能について、要求・設計・画面仕様・検証計画を管理する。対象範囲は[ADR-0001](adr/0001-nine-feature-scope.md)を参照する。文書のdoneはレビュー完了を表し、アプリの実装・検証完了を意味しない。

| 読む目的 | 正本・参照先 |
| :--- | :--- |
| 運用・進行・レビュー | [運用インデックス](operations/OPERATIONS.md) |
| 要求・責務・受け入れ基準 | [Layer 1 REQ](req/REQ.md) |
| DDD・契約・共通スキーマ・構成 | [Layer 2 SPEC](spec/SPEC.md) |
| 境界・集約・値型・Port・契約の共通規則 | [共通アーキテクチャ](spec/architecture.md) |
| OpenAPI・JSON Schemaと構造検証例 | [公開契約](spec/contracts/README.md) |
| 画面とコンポーネント仕様 | [screens.drawio](spec/screens.drawio)（SCR-001〜008） |
| ケース・合否基準・実施結果の入口 | [Layer 3 VERIFY](verification/VERIFY.md) |
| 対象範囲などの横断判断 | [ADR一覧](adr/ADR.md) |
| レビュー結果とコードの未対応箇所 | [STATUS](STATUS.md) |

参照優先順位は運用 → REQ → SPEC → VERIFY。実装は設計に追従させる。レガシー資料と互換案内は削除済み。以前の版が必要な場合はGit履歴（`9f30200`）を参照する。

日次・履歴は指定timeZoneの暦日/暦月、予算は開始日基準の家計期間。業務保存・参照はAWS API経由で、端末DBを置かない。UI閾値は600/840。詳細は各機能の正本を参照する。

過去の無料枠・料金試算・実装済み表記を現行の確定条件や検証合格として扱わない。関連Issueは[支出管理機能を追加する #1](https://github.com/tombee-studio/self-management-app/issues/1)。

全9機能をDDD＋契約駆動で設計し、操作契約31件・HTTP読取補助3件を定義する。HTTP版3・内部イベント版2・操作契約版2を管理し、[ADR-0003](adr/0003-cloud-api-only.md)と99件の検証計画へ対応付ける。途中実装は未適合。

## AWS APIへの保存方式変更

[ADR-0003](adr/0003-cloud-api-only.md)により端末DBを廃止。アプリはAPI Gateway/Lambda経由でDynamoDBを読み書きする。API版3の設計は[SPEC](spec/SPEC.md)、検証計画は[VERIFY](verification/VERIFY.md)。既存実装は旧方式であり未適合。
