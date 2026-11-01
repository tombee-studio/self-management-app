# iris 支出管理

- バージョン: v3.0.0
- ステータス: done

FlutterアプリとAWS API版3の実装です。正本は [REQ](docs/req/REQ.md)、[SPEC](docs/spec/SPEC.md)、[VERIFY](docs/verification/VERIFY.md) です。

アプリはHTTP Command/Queryだけで支出・カテゴリ・予算を読み書きします。表示・入力・結果不明要求はセッションのメモリに保持します。端末DB、永続キャッシュ、同期キュー、旧Push/Pullは使用しません。端末に以前のDBがあっても読み込み・アップロード・消去しません。

## 開発と検証

```sh
flutter pub get
npm ci --prefix server
flutter analyze
flutter test
npm test --prefix server
python3 tool/check_architecture.py
python3 tool/check_icons.py
terraform -chdir=terraform validate
```

アイコン検査にはPythonのPillowが必要です。`server/test`はインメモリのUnitOfWorkとDynamoDB要求のprovider代替を使い、実AWSには接続しません。共通fixtureは `node tool/generate_fixtures.cjs`、契約の同期は `python3 tool/sync_contracts.py` で再生成します。Schemaの正本は `docs/spec/contracts` です。

## 構成

- `lib/cloud`: HTTP Port、厳密なDTO検証、要求IDを固定した再送、メモリ表示状態。
- `lib/presentation`: 日次・履歴・支出入力・予算・カテゴリ・決済連携・接続設定。
- `server/domain`: 値制約、カテゴリ解決、決済正規化、暦日・予算Policy。
- `server/application`: Command/Query、Receipt/CAS/世代、Undo、イベント配送。
- `server/infrastructure`: DynamoDB UnitOfWork、署名トークン、クラウド移行。
- `server/api`: HTTP adapterと公開契約検証。

保存応答が不明な場合、入力を固定し「同じ要求で再試行」を使います。競合時は入力を保持し、最新版を確認します。再取得に失敗しても、確定済みの保存結果は取り消しません。

## AWSへの切替と検証

[Terraform手順](terraform/README.md)に従い、stg環境への配布・実AWS連動およびiOS 18.4 Simulator連動による全99必須ケースの検証を完了しています。詳細は [検証結果](docs/verification/VERIFY.md) を参照してください。
