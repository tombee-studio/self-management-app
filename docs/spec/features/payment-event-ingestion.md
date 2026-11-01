# 外部決済イベント連携 設計

- **バージョン**: v1.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/payment-event-ingestion.md)。設計の正本は本書。

## ドメイン境界・モデル

分類: **PaymentIntegrationの腐敗防止層と台帳取り込みApplication**。[共通アーキテクチャ](../architecture.md)と[ADR-0002](../../adr/0002-domain-contract-design.md)に従う。全契約はv1.0.0。既存REQの業務範囲・AC番号を維持する。

| モデル | 所有・構成・制約 |
| :--- | :--- |
| PaymentInputDTO（境界DTO） | source、externalId?、amount表記、currency、merchant?、spentAt?。rawPayloadをDomainへ渡さない |
| NormalizedPayment（値） | MoneyJPY、SpentAt、MerchantKey、source、ExternalTransactionKey?。Expense集約の複製ではない |
| IngestionDecision（結果） | Created(expenseId)/Duplicate(expenseId)/Rejected。台帳が支出の所有者 |

### 不変条件・依存方向

- 外部IDはsourceとの組で一意。IDなしはsource/金額/店舗キー/180秒の重複ポリシーを満たす。
- 重複検査・作成・Outboxを同一台帳UoWで実施し、並列送信で2件作らない。
- 不正入力は未確定明細として保持せず、rawPayloadを通知・ログ・台帳へ保存しない。

PaymentAdapterPort、LedgerIngestionPort、CategoryClassificationPolicy/CategoryLookup、OwnerLeasePort（Lambda）、NotificationPort、Clock。HTTP/URL Adapter → IngestPaymentHandler → LedgerIngestionPort。分類Policyは純粋関数、保存は台帳Handlerが所有する。公開LedgerIngestionPortはLedger所有のImportedExpenseDraft（amount/spentAt/merchantMemo/merchantKey/source/externalTxId）を受け取り、ACLがNormalizedPaymentから変換する。

### 公開契約

契約の成功・失敗・版・トランザクション・再試行の共通意味は[共通規則](../architecture.md#5-契約の共通規則)。Operationの引数型は上の値型/DTOとSPEC-01の項目定義を使い、DB行型を公開しない。QueryのsnapshotIdとVersionは互換ではない。

<a id="pay-c01"></a>
#### PAY-C01: NormalizePayment

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `NormalizePayment{inputDto,receivedAt} → Result<NormalizedPayment>` |
| 事前条件 | 対応source=apple_pay。currency未指定はJPY、指定ならJPY |
| 成功後の保証・変更範囲 | 金額・日時・メモを値型へ変換。日時省略だけreceivedAt、指定不正は拒否。永続化なし |
| 失敗 | ValidationFailed/UnsupportedSource |
| 冪等性・再試行 | 同receivedAtと同入力で同じ値。DBや通知に副作用なし |
| 対応REQ | [AC-01](../../req/features/payment-event-ingestion.md#ac-01), [AC-04](../../req/features/payment-event-ingestion.md#ac-04) |

<a id="pay-c02"></a>
#### PAY-C02: IngestPayment

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `IngestPayment{normalizedPayment} → Result<IngestionDecision>` |
| 事前条件 | 正常化済み値、所有者範囲、カテゴリLookup成立 |
| 成功後の保証・変更範囲 | 台帳UoW内で重複判定。新規のみExpense作成・版・Outbox。未知/削除済み分類先は未分類 |
| 失敗 | ValidationFailed/Busy/StorageFailure |
| 冪等性・再試行 | 外部ID再送はDuplicate、IDなしは180秒以内条件でDuplicate。新規IDを再採番して2件作らない |
| 対応REQ | [AC-01](../../req/features/payment-event-ingestion.md#ac-01), [AC-02](../../req/features/payment-event-ingestion.md#ac-02), [AC-05](../../req/features/payment-event-ingestion.md#ac-05) |

<a id="pay-c03"></a>
#### PAY-C03: SubmitBackgroundPayment

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `SubmitBackgroundPayment{GET/POST PaymentInputDTO} → HTTP Created|Duplicate|Error` |
| 事前条件 | OpenAPIに一致、固定owner、POST本文優先 |
| 成功後の保証・変更範囲 | 前面起動不要でクラウドへ保存。ローカルは後続同期で反映。lease中だけ重複検査〜保存を直列化 |
| 失敗 | 400入力/403owner/409Busy/500保存失敗 |
| 冪等性・再試行 | 同外部IDで再試行。lease失効・再取得後も重複検査する |
| 対応REQ | [AC-03](../../req/features/payment-event-ingestion.md#ac-03), [AC-06](../../req/features/payment-event-ingestion.md#ac-06) |

<a id="pay-c04"></a>
#### PAY-C04: PresentIngestionResult

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `PresentIngestionResult{decision,notificationPermission} → PresentationDecision` |
| 事前条件 | Createdはcommit済み、expenseIdが存在 |
| 成功後の保証・変更範囲 | 許可時にcommit後通知、拒否時SnackBar。通知タップはMAN編集を開き、削除済みは今日画面の案内 |
| 失敗 | 通知拒否はWarning。DB取得失敗はStorageFailure |
| 冪等性・再試行 | 重複判定結果では成功通知を増やさない |
| 対応REQ | [AC-07](../../req/features/payment-event-ingestion.md#ac-07) |

## SPEC-01: 入力経路・正規化

SCR-002。連携設定画面にApple Payショートカットの設定ガイド、接続状態、テスト送信、結果を表示する。OSから他アプリの決済を直接傍受する機能は提供しない。対応経路は`iris://add-expense`によるアプリ取り込みと、ショートカットから`GET/POST /payment`への背景登録。

共通イベントはsourcePlatform（apple_pay）、externalTransactionId（任意）、amount（JPY整数）、currency（JPY）、merchantName（任意）、spentAt（ISO8601）、paymentMethodDetail（任意）、rawPayload（処理中のみ）。金額は共通制約。外部表記の¥・カンマ・空白を除いた数値を検証し、四則演算や不正な文字列は評価しない。時刻省略は受信時刻、指定されていて解析不能なら拒否。店舗名はメモ制約に合わせ100文字で切り、通知・ログへrawPayloadを保存しない。

HTTP/URL/Shortcut adapter → NormalizePaymentHandler（ACL） → IngestPaymentHandler → LedgerIngestionPort。台帳が唯一の支出保存責務を持ち、PaymentにExpenseRepositoryの具象DBを注入しない。 同じ正規化・分類・重複判定ルールをLambda側にも実装する。Lambdaは所有者単位の条件付きロックレコード（有効期限付き）で重複検索から保存までを直列化し、競合時は再試行可能な409を返す。期限切れを再取得でき、保存後にロックを解放する。IDありはsource+externalTxIdで一意。IDなしはsource・amount・正規化店舗名が一致しspentAt差が180秒以内なら重複。重複判定・挿入・outboxを直列化した単一トランザクションで行う。

分類は店舗名をNFKC・lowercaseし、交通（JR/東京メトロ/Suica/タクシー/ENEOS）、日用品（マツモトキヨシ/ウエルシア/ダイソー）、食費（セブン/ローソン/ファミリーマート/マクドナルド/スタバ）の順で一致する有効なカテゴリを使用する。該当カテゴリが削除済み、または一致なしなら未分類。

## SPEC-02: API・通知・同期

`/payment`はuser_idまたはx-user-id、amount、merchant、spent_at、source、external_tx_idを受け取る。GETはクエリ、POSTはJSON。同じフィールドを両方に指定した場合はPOST本文を優先。成功は200と`{status:created,expense_id}`、重複は200と`{status:duplicate,expense_id}`、不正入力は400と機械可読errorを返す。保存失敗は500、呼び出し元が再送するときは同じ外部IDを保持する。

背景経路はLambdaでクラウドへ保存し、アプリ起動・復帰の同期でローカルへ反映する。通知はショートカットの「通知を表示」で行う。アプリ内経路は保存成功後、許可があればローカル通知、拒否ならSnackBarのみ。通知payloadはexpense_idだけとし、タップ時に該当明細の編集を開く。すでに削除済みなら案内して今日画面へ戻る。

## SPEC-03: 異常系・理由

APIやURLの不正入力を未確定明細として保存しない。取り込み成功・重複・失敗を画面・レスポンスで区別する。ネットワークなしでは背景APIは失敗をショートカットへ返し、アプリ内のローカル記録は継続できる。アプリ自体のロック中DB書き込み・App Intentの実装を必須経路にせず、背景記録と前面起動の責務を分離する。

## REQ対応・検証入口

- [payment-event-ingestion/AC-01](../../req/features/payment-event-ingestion.md#ac-01): 本書のSPEC-01〜03で具体化。
- [payment-event-ingestion/AC-02](../../req/features/payment-event-ingestion.md#ac-02): 本書のSPEC-01〜03で具体化。
- [payment-event-ingestion/AC-03](../../req/features/payment-event-ingestion.md#ac-03): 本書のSPEC-01〜03で具体化。
- [payment-event-ingestion/AC-04](../../req/features/payment-event-ingestion.md#ac-04): 本書のSPEC-01〜03で具体化。
- [payment-event-ingestion/AC-05](../../req/features/payment-event-ingestion.md#ac-05): 本書のSPEC-01〜03で具体化。
- [payment-event-ingestion/AC-06](../../req/features/payment-event-ingestion.md#ac-06): 本書のSPEC-01〜03で具体化。
- [payment-event-ingestion/AC-07](../../req/features/payment-event-ingestion.md#ac-07): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。

## 契約検証・実装への移行

[機能別検証計画](../../verification/features/payment-event-ingestion.md)のTC-CTで公開契約ごとの前提違反・成功保証・不変条件・失敗時副作用・再試行を検証する。既存SPEC-01〜03の業務/画面条件を契約の詳細規則として維持する。既存実装と途中の変更は移行元であり、本設計に適合済みとは扱わない。
