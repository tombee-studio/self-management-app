# 外部決済イベント連携 設計

- **バージョン**: v0.4.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/payment-event-ingestion.md)。設計の正本は本書。

## SPEC-01: 入力経路・正規化

SCR-002。連携設定画面にApple Payショートカットの設定ガイド、接続状態、テスト送信、結果を表示する。OSから他アプリの決済を直接傍受する機能は提供しない。対応経路は`iris://add-expense`によるアプリ取り込みと、ショートカットから`GET/POST /payment`への背景登録。

共通イベントはsourcePlatform（apple_pay）、externalTransactionId（任意）、amount（JPY整数）、currency（JPY）、merchantName（任意）、spentAt（ISO8601）、paymentMethodDetail（任意）、rawPayload（処理中のみ）。金額は共通制約。外部表記の¥・カンマ・空白を除いた数値を検証し、四則演算や不正な文字列は評価しない。時刻省略は受信時刻、指定されていて解析不能なら拒否。店舗名はメモ制約に合わせ100文字で切り、通知・ログへrawPayloadを保存しない。

`PaymentEventAdapter` → `ApplePayEventAdapter` → `PaymentIngestionService` → `ExpenseRepository`。同じ正規化・分類・重複判定ルールをLambda側にも実装する。Lambdaは所有者単位の条件付きロックレコード（有効期限付き）で重複検索から保存までを直列化し、競合時は再試行可能な409を返す。期限切れを再取得でき、保存後にロックを解放する。IDありはsource+externalTxIdで一意。IDなしはsource・amount・正規化店舗名が一致しspentAt差が180秒以内なら重複。重複判定・挿入・outboxを直列化した単一トランザクションで行う。

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
