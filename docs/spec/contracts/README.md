# 公開契約の機械可読定義

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

| 正本 | 内容 |
| :--- | :--- |
| [共通DTO](shared.schema.json) | 操作ごとのCommand/Query入力・応答、金額・日時・エラー、UI/アセット |
| [OpenAPI](openapi.json) | API版3。/commands、/queries、/payment、/health |
| [イベント](events.schema.json) | Lambda内部のイベントenvelope/payload、schemaVersion=2 |
| [構造検証例](examples.json) | 正常/異常15例。アプリの適合結果ではない |

操作契約v2.0.0、HTTP schemaVersion=3、内部イベントschemaVersion=2を区別する。端末DB版は存在しない。旧wire版2とPush/Pull Change/Record/ACKを削除し、旧同期操作IDは[クラウド機能書](../features/aws-cloud-database-sync.md#廃止契約の追跡)で追跡する。イベント版2はCategoryRetired payloadのmovedExpenseIdsを件数へ変更するためのmajor改訂である。

`POST /commands`のoperationでMAN-C01〜04、BUD-C01/C03、CAT-C01〜04を選び、requestIdを必須とする。EnsureDefaultCatalogは空入力、ownerはヘッダーから決定する。全CommandはサーバーReceiptで再送を処理する。EvaluateBudgetThresholdsのHTTP入力は日付/TimeZoneで、内部Policy用plan/summaryはサーバーが取得する。

`POST /queries`はDASH-C01/C02、HIST-C01/C02、BUD-C02とGetExpense/GetCatalog/GetBudgetPlanを提供する。BUD-C02のplan/periodExpensesはサーバーが同一世代で取得してPolicyへ渡す。GetExpenseは削除済み404、GetBudgetPlanは未設定404、GetCatalogはEnsureDefaultCatalog成功後に利用する。いずれも業務状態を変更しない。Get系3操作はHTTP読取契約HTTP-Q01〜03としてVERIFY共通ケースで追跡する。

PAY-C03はGET/POST /payment。requestIdとamountを必須とし、user_idかx-user-idのいずれかを必須とする。両方ある場合の不一致は403。GETはクエリ、POSTはJSON本文のみを入力とし、POSTのクエリ入力は受け付けない。金額表記とRFC3339入力はACLで正規化し、内部へrawPayloadを漏らさない。

WatchDailySummaryという既存操作名は追跡のため維持するが、APIは1要求1応答で常時購読ではない。再取得の起動条件は共通アーキテクチャに従う。

内部のCloseExpenseDraft/SelectHistoryDate/UI/ICONはHTTPへ公開しない。PAY-C01/C02はLambda内部の契約、PAY-C04はアプリの通知/表示契約。CloudAccess契約はHTTP呼出しのアプリ内調整で、独立した業務保存口を増やさない。

Schemaは表現形式、カテゴリ存在・版・grapheme・原子性・IANA timeZone・日界・通知receiptはDomain/Port契約テストで検証する。Resultのoperationとvalue型をoneOfで結び、別操作の応答を受け付けない。HTTPでは全属性camelCaseを基本とし、既存Shortcut互換の/paymentの外部入力/expense_idだけsnake_caseを維持する。

OwnerIdは識別子で認証資格ではない。認証追加は今回対象外。旧APIの混在書込停止、providerの版3対応、新consumer切替の順で導入する。実装やデプロイは本書更新に含めない。

初回ConfigureBudgetPlanはexpectedVersion=0、以後は正の集約版。CommandResponseのreadGenerationはcommit済みowner世代で、QueryResponseは返却データの世代。サーバー由来の生のSDK例外はErrorへ変換する。内部Policy固有エラー（SnapshotMismatch/UnsupportedSource等）はHTTP境界でValidationFailed等へ明示変換する。

起動時はEnsureDefaultCatalogを先に実行し、GetCatalog/GetBudgetPlan等を取得する。Budget未設定404は予算未設定UIとして表示し、ConfigureBudgetPlan(expectedVersion=0)で作成する。GET /paymentのamountはクエリ文字列をACLで変換し、requestIdはUUIDとして検証する。
