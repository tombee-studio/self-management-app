# AWS API版3の配布・切替

- バージョン: v3.0.0
- ステータス: draft

API Gateway → Lambda (`server/`) → DynamoDBの構成です。新しいownerId/idの5テーブルは既存テーブルと別名で作成し、旧データを置換しません。`api_v3_enabled`の初期値はfalseです。認証方式は現行設計どおり追加していません。

## ローカル検証

```sh
npm ci --prefix server
npm test --prefix server
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
```

Lambda ZIPは `server/` とロック済み依存から作成します。`cursor_secret`は32文字以上の永続的なHMAC鍵を安全な変数経路で指定します。端末へ配布しません。`owner_id`、region、environment、費用通知先、`monthly_budget_usd`も配布時に指定します。

## 切替順序

1. 旧5テーブルをバックアップし、旧APIの書き込みを停止する。旧APIと新APIの混在書き込みを許可しない。
2. `api_v3_enabled=false`のplanで旧テーブルが削除・置換されないことを確認して新テーブルとLambdaを配布する。まだ新アプリを有効にしない。
3. サーバー側でdocument-client JSONのバックアップを用意する。形式は `{ownerId,categories,expenses,budgets,categoryBudgets}`。旧項目のsnake_case名を維持する。
4. `node tool/migrate_cloud.cjs backup.json OWNER_ID migration.json` を実行する。バックアップは変更せず、既存ID・件数・金額・カテゴリ対応・版・世代・外部ID索引を作成する。端末DBは対象外。
5. テーブル対応JSON `{expenses,categories,budgets,metadata,events}` に新テーブル名を記入し、隔離環境で検証してから `node tool/import_cloud.cjs migration.json tables.json --legacy-writes-stopped` で空の移行先へ登録する。件数・ID・総額・カテゴリID比較が不一致なら登録分を取り消す。失敗時は旧バックアップと旧APIへ戻し、新アプリを切り替えない。ロールバック失敗は新APIを閉じたまま再実施・復旧する。
6. 新APIのconsumer/provider・CAS・再送・Query世代・イベント・Undo・実機検証後、`api_v3_enabled=true`のplanを確認して有効化する。
7. アプリのHTTPS接続先を切り替える。初期カテゴリはEnsureDefaultCatalogで冪等作成する。旧API書込は停止したまま維持する。

この作業ではapply、クラウド移行、本番切替は実行していません。`terraform plan`は隔離AWSの資格情報・変数・移行条件を用意した配布時に確認します。

## 費用計測

月500円は運用目標です。通知閾値はUSD入力で、課金停止の上限ではありません。region、件数、平均項目サイズ、全件検索回数、Lambda実行時間、API要求数、実際の為替・請求を記録して判断します。検索は全ページを強整合取得するため、保存件数と再取得頻度に比例して費用が増えます。固定の無料枠・為替・料金から達成を保証しません。

取引のIAMは個々のPut/Get/Delete/Update権限とConditionCheckItemを使います（[AWS公式: Using IAM with DynamoDB transactions](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis-iam.html)）。アプリへIAM資格情報は渡しません。

LambdaはNode.js 22を使用します（[AWS公式ランタイム一覧](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html)）。SDKはランタイム内蔵版に依存せず、server/package-lock.jsonの依存をZIPへ同梱します。
