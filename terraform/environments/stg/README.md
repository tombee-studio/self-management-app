# stg連動検証

- バージョン: v0.1.0
- ステータス: draft

本番とは別のローカルstate・environment=stg・検証専用ownerでAPI版3を配布する。`secrets.auto.tfvars`とstate/planはGitへ登録しない。`cursor_secret`は永続的なHMAC鍵で、初回生成後は保持する。

```sh
terraform -chdir=terraform/environments/stg init
terraform -chdir=terraform/environments/stg plan -out=stg.tfplan
terraform -chdir=terraform/environments/stg apply stg.tfplan
```

planはstgだけを対象として確認する。stgでは専用費用通知を増やさず、既存のアカウント費用通知とstgのCloudWatch計測を使う。旧テーブル形式の空テーブルも共通moduleの構成として保持する。既存の本番stateを読み込まない。

iOSアプリは `--dart-define=IRIS_API_ENDPOINT=<stg HTTPS URL>` と `--dart-define=IRIS_OWNER_ID=<検証owner>` を指定する。指定しない通常ビルドの既定値は変更しない。

連動テストは `tool/verify_stg.cjs`、`tool/verify_stg_boundaries.cjs`、`tool/verify_stg_delivery.cjs`、`tool/run_stg_ios.py`。設定JSONは `{environment:"stg",endpoint,owner,tables}` を `/private/tmp/iris-stg-config.json` に配置する。providerテストは初期状態で実行し、以後のUI検証データは識別子を変えて登録する。検証対象はstg専用ownerのみ。

結果は [stg証跡](../../../docs/verification/results/evidence/stg-2026-11-02/) に記録する。
