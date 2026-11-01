# AGENTS.md - エージェント開発ガイドライン

- **バージョン**: v2.0.0
- **ステータス**: done

## ドキュメント階層

上位を正とし、Layer 0（運用） > Layer 1（要求: REQ） > Layer 2（設計: SPEC） > Layer 3（検証: VERIFY）の順に従う。

タスク着手・作成・レビュー時には、[運用インデックス](docs/operations/OPERATIONS.md)、[要求運用](docs/operations/01_REQ.md)、[設計運用](docs/operations/02_SPEC.md)、[検証運用](docs/operations/03_VERIFY.md)、[ADR運用](docs/operations/ADR.md)、[実装運用](docs/operations/IMPL.md)をすべて読み、各レイヤーのインデックスと対象機能の文書を確認する。

| レイヤー | 管理場所 | 役割 |
| :--- | :--- | :--- |
| Layer 0 | `AGENTS.md`、`docs/operations/` | 運用・ステータス・レビュー・移行ゲート |
| Layer 1 | [REQ](docs/req/REQ.md)、`docs/req/features/<機能名>.md` | 背景、目的、スコープ、ユースケース、受け入れ基準 |
| Layer 2 | [SPEC](docs/spec/SPEC.md)、`docs/spec/features/<機能名>.md`、`docs/spec/screens.drawio` | 振る舞い、UI、入出力、業務ルールとアーキテクチャ、データモデル、状態管理、API、コンポーネント構成 |
| Layer 3 | [VERIFY](docs/verification/VERIFY.md)、`docs/verification/features/<機能名>.md`、`docs/verification/results/<機能名>.md` | 検証計画・ケース・結果・証跡 |

## 実装と移行ゲート

実装・自動テストはコード成果物でありレイヤーには含めない。REQ確定 → SPEC確定 → VERIFY計画確定 → 実装・検証 → VERIFY結果確定の順に進む。各確定には当該レイヤーの全ドキュメントとインデックスの `done` が必要。実装前の結果文書は不要。計画確定と検証完了を混同しない。結果登録後の扱いは検証運用に従う。

実装はLayer 2の設計に忠実に従い、Layer 3の確定済み計画で検証する。矛盾・制約・考慮漏れがあれば、該当する上位文書を先に修正・確定し、影響する下位文書と実装へ同期する。

## ステータスとコミット

- `draft`: 作成・編集中。
- `wip`: 未完了だがownerが中間コミットを承認した状態。次工程へは進めない。
- `review`: レビュー中。
- `done`: `/ai-docs` のレビュー工程で整合性・完了条件を確認した状態。developマージで正式確定。

既存文書を変更するときも対象文書とインデックスを直ちに `draft` に戻す。再度 `/ai-docs` のレビュー工程を通過するまで `done`・`wip` に戻さない。`/ai-docs` は編集後に内蔵のレビュー工程を実行し、レビュー判定まで行う。編集段階ではコミットせず、PASS時のコミットはレビュー手順に従う。`/ai-docs` のレビュー工程のPASS時は `done` にしてコミットし、FAIL時はコミットしない。未完了の文書を `wip` にしてコミットする場合は、必ずownerの承認を得る。

## 横断する意思決定記録（ADR）

[ADR一覧](docs/adr/ADR.md)と[ADR運用](docs/operations/ADR.md)に従い、要求・設計・検証にまたがる判断を `docs/adr/` に記録する。ADRは新しいレイヤーではなく、正本とdoneゲートを置き換えない。`/ai-docs ADR <判断の概要>` で作成し、レビューまで実行する。

## 機能単位の集約

要求・設計・検証の追加時は既存の機能一覧と関連文書を先に確認し、目的・責務・ユースケースが共通する内容は既存機能の文書・一覧行へ集約する。追加依頼や変更のたびに別機能・別文書を増やさない。新規機能として分けるのは独立した責務・スコープがある場合とし、既存機能との差と分割理由を記録する。具体的な判断・同期・レビューは [運用ルール](docs/operations/OPERATIONS.md) の「機能単位の集約と重複防止」に従う。
