# 公開契約の機械可読定義

- **バージョン**: v1.0.0
- **ステータス**: done

| 正本 | 内容 |
| :--- | :--- |
| [共通DTO](shared.schema.json) | 金額・時刻・ID・エラー・変更/記録・UI/アセット入力 |
| [OpenAPI](openapi.json) | SYN-C02/C07、PAY-C03のHTTP consumer/provider契約 |
| [ドメインイベント](events.schema.json) | 内部イベントenvelopeと種類別payload |
| [構造の検証例](examples.json) | 正常・異常15ベクトル。実アプリの検証結果ではない |

設計の意味・Port・事前/事後条件・失敗時保証は[共通アーキテクチャ](../architecture.md)と各機能書で定義する。JSON Schemaは表現形式の契約であり、カテゴリの存在、集約版の一致、100grapheme、日界・トランザクション原子性はDomain/Port契約テストで検証する。`x-graphemeMaxLength`は意味検証の注記で、標準maxLengthと同じ文字数とは扱わない。

PushのChangeは送信元revisionを必須とする。Pull/ConflictのRecordにはrevisionを公開しない。保存行に残る送信元revisionを別レプリカのACKに流用せず、ACKは当該Push要求へ対応するentityKey/revisionだけを返す。OwnerIdは要求境界で解決し、個別Domain Recordへ混入させない。

wire版2、内部イベントschemaVersion=1、設計契約版1.0.0、DB版3は別の版体系。互換v1のmerchant_name/icon_nameや未知の支払い方法の読み替えはACL内だけに置く。既定のスキーマは正規化後の公開形を定義し、互換DTOをDomainへ漏らさない。

同じ契約を使うDart/Nodeのconsumer/providerは共通fixtureで型・エラー・冪等性を確認する。公開形を変える場合は対応consumer・VERIFY計画・契約版を同じ変更で更新する。

導入順はproviderのwire版2対応と契約テストを先行し、その後consumerを切り替える。v1互換の読み替えはACLで維持し、未対応providerへの切替でOutboxを消去しない。対応版不一致は失敗として表示し、ローカル変更を保持する。SYN-C03は受信ページをDomainへ適用する内部契約で、GETの取得契約SYN-C07と区別する。
