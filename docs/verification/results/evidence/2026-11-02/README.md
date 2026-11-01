# ローカル実行証跡

- バージョン: v0.1.0
- ステータス: draft
- 実施日: 2026-11-02（JST）

対象は基点07565d97526a86d956dfab1c5f5cae9897fc9cbfと作業ツリー。manifest.jsonでソースのSHA-256と環境・コマンドを固定する。Flutter/NodeテストログのPASSはそのfixtureのみを保証し、全99必須ケースの実AWS/実機確認を保証しない。検証データは隔離ownerと固定時計を使い、本番データ・AWS applyには接続しない。

- flutter-test.txt: 単体・Widget。
- server-test.txt: Domain/Application、DynamoDB要求provider代替、イベントconsumer、クラウド移行代替provider。
- analyze.txt: Flutter静的解析。
- terraform-validate.txt: Terraform構成の検査。
- checks.txt: 依存方向・契約同期・アイコン寸法/参照/不透明。
- builds.txt: ネイティブビルドの結果と制限。

レビューは必須環境確認の未実施を理由にFAIL。draft維持、コミットなし。
