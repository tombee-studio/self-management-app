---
name: spec
description: /spec <仕様概要> の設計追加・更新を、現行REQ・SPEC・VERIFY運用に従って進める。
---

# 設計追加・更新

- **バージョン**: v2.1.0
- **ステータス**: done

`/spec <概要>`を受け、[ai-docs](../ai-docs/SKILL.md)の診断・レビュー手順で設計を追加・更新する。

1. [運用](../../../docs/operations/OPERATIONS.md)と全運用文書、[REQ](../../../docs/req/REQ.md)、[SPEC](../../../docs/spec/SPEC.md)、[VERIFY](../../../docs/verification/VERIFY.md)を読む。
2. 対応要求が未確定ならREQを先に具体化・レビューする。目的・責務が共通する内容は既存機能へ集約する。
3. REQ全件done後、`docs/spec/features/<機能名>.md`に振る舞いと詳細設計をまとめ、SPEC一覧の対応行を同期する。UIがあれば`docs/spec/screens.drawio`の該当画面と同じキャンバス上のコンポーネント仕様も同期する。
4. 対象文書・索引をdraftに戻して編集し、ai-docsの内蔵レビューで判定する。コミット・done更新はその判定に従う。
5. 検証計画が未確定なら実装準備完了とは報告しない。依頼範囲外の実装へ自動進行しない。

設計の正本はSPECへ集約する。削除済みのレガシー資料・互換案内を再作成しない。
