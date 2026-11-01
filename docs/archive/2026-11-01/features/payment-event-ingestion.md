# 外部決済イベント連携 設計（既存資料の統合）

- **バージョン**: v0.1.0
- **ステータス**: draft
- **資料区分**: 過去資料（現行仕様・工程ゲートの対象外）
- **整理日**: 2026-11-01（JST）

対応要求: [要求案](../../../req/features/payment-event-ingestion.md)。要求がdraftのため、本書は未確定の既存設計資料として保管する。

## 保存時点の移行範囲と確定条件

既存の仕様・詳細設計を同一文書へ移した。以下の保存節は当時の案であり、実装との一致・検証完了を保証しない。重複や矛盾は採用判断をせず保持し、[差分一覧](../../../STATUS.md)へ記録した。REQ確定後に振る舞い・データモデル・状態管理・異常系を同期し、レビューする。

追加項目は親機能へ集約: `apple-pay-background-sync`。同じ対象データ・操作の拡張であり、独立した機能として重複登録しない。

## 保存資料: payment-event-ingestion / 仕様

移行元: `docs/spec/features/payment-event-ingestion.md`。旧節番号とコード例を保持。

### 外部決済イベント連携基盤＆Apple Payアダプタ (payment-event-ingestion) 仕様書

#### 1. 目的・概要
Apple Pay をはじめとする各種決済サービス（将来的な Google Pay、PayPay、クレジットカード明細連携等を含む）で支払いが発生した際に、各サービス固有の決済通知・イベントを検知し、統一されたフォーマットへ正規化（アダプターパターン）して自動的に支出を記録する。
これにより、手入力の手間や記録忘れをなくし、シームレスな自動家計簿体験を提供する。

---

#### 2. アーキテクチャ方針（アダプターパターン）

本機能は、特定の決済プラットフォームに密結合させず、サービスごとの差異をアダプター層で吸収する設計とする。

1. **イベントレシーバー (Event Receiver)**:
   - OS固有の仕組み（iOS App Intents / Shortcuts、URLスキーム、Webhook等）から生データを受信する。
2. **決済イベントアダプター (Payment Event Adapter)**:
   - 各サービス固有のペイロードを共通モデル `NormalizedExpenseEvent` へ変換・正規化する。
   - 初期実装として **Apple Pay アダプタ (`ApplePayEventAdapter`)** を提供する。
3. **インジェスチョンサービス (Ingestion Service)**:
   - 重複判定・排除、カテゴリ自動推定、支出データ保存、およびローカル通知発行を行う。

---

#### 3. ユーザーフロー・画面要件

##### 3.1 ユーザーフロー（Apple Pay 連携時）
1. **初期設定**:
   - ユーザーはアプリ内「設定 > 外部決済連携 > Apple Pay」を開き、iOS「ショートカット」アプリ用のオートメーション設定手順を確認・設定する。
2. **決済発生時**:
   - ユーザーが店舗等で Apple Pay で決済を完了する。
   - iOS オートメーションがバックグラウンドで起動し、当アプリの App Intent（またはカスタムURL）を呼び出す。
3. **自動記録と通知**:
   - アプリが取引を受信・正規化し、ローカルDBへ支出を保存。
   - 端末にローカルプッシュ通知を発行（「Apple Payの支払いを記録しました: ¥1,280 (セブン-イレブン)」）。
4. **確認・カテゴリ修正**:
   - ユーザーが通知をタップすると、クイック確認モーダルが開き、自動推定されたカテゴリの確認・変更を即座に行える。

##### 3.2 画面要件
- **画面構成および画面仕様 (draw.io)**: [docs/spec/screens.drawio](../../../spec/screens.drawio) （タブ: `外部決済連携設定`）
  - 外部決済連携管理画面（連携対応サービス一覧、ステータス表示）
  - Apple Pay 連携詳細ガイド画面（オートメーション設定手順の解説）
  - 決済検知クイック確認モーダル（金額、店舗名、カテゴリワンタップ選択）

---

#### 4. 共通イベント仕様 (NormalizedExpenseEvent)

すべての決済アダプタは、外部イベントを以下の共通フォーマットへ変換する。

| 項目名 | 型 | 必須 | 説明 | 例 |
| :--- | :--- | :---: | :--- | :--- |
| `sourcePlatform` | string | ○ | 決済プラットフォーム識別子 | `'apple_pay'` |
| `externalTransactionId` | string | - | 外部サービスの取引一意ID | `'tx_20261003_123456'` |
| `amount` | number | ○ | 支払金額（正の整数または小数） | `1280` |
| `currency` | string | ○ | 通貨コード（ISO 4217） | `'JPY'` |
| `merchantName` | string | - | 加盟店名・店舗名 | `'セブン-イレブン 渋谷店'` |
| `spentAt` | string | ○ | 決済日時（ISO 8601） | `'2026-10-03T12:30:00Z'` |
| `paymentMethodDetail` | string | - | 決済手段の詳細・カード名 | `'三井住友カード (iD)'` |
| `rawPayload` | object | ○ | デバッグ・監査用の生データ | `{ ... }` |

---

#### 5. ビジネスロジック・処理ルール

##### 5.1 重複記録防止 (Deduplication)
- **IDベース判定**: `externalTransactionId` が提供されている場合、過去に同一IDの記録が存在すればスキップ。
- **タイムスタンプ＆金額ベース判定**: IDが存在しない場合、「同一金額」かつ「同一店舗名」かつ「決済日時が前後3分以内」の記録が既に存在する場合は同一決済とみなし重複排除する。

##### 5.2 カテゴリ自動推定ルール
店舗名（`merchantName`）に含まれるキーワードからカテゴリを初期判定する。
- 例:
  - 「セブン」「ローソン」「ファミリーマート」「マクドナルド」「スタバ」→ **食費**
  - 「JR」「東京メトロ」「Suica」「タクシー」「ENEOS」→ **交通費**
  - 「マツモトキヨシ」「ウエルシア」「ダイソー」→ **日用品**
- キーワードに一致しない場合は「**未分類**」として登録し、通知タップ時のクイック編集を促す。

---

#### 6. エラーハンドリング・エッジケース

- **不正な金額・パラメータ**:
  - 金額が 0 以下または数値変換できない場合は、エラーログを記録し支出としては計上しない（または「要金額入力」の未確定明細として保持）。
- **バックグラウンド実行時の制約**:
  - 端末スリープ時やアプリ未起動時でも、App Intent 経由でローカルDB（SQLite等）に安全にトランザクション書き込みを行えるように設計。
- **通知オフ時のフォールバック**:
  - 通知許可が得られていない場合でも、支出データ自体はサイレントに記録され、次回アプリ起動時に「新しく記録された支出」としてダッシュボード上で通知バッジを表示。

## 保存資料: payment-event-ingestion / 詳細設計

移行元: `docs/implementation/features/payment-event-ingestion.md`。旧節番号とコード例を保持。

### 外部決済イベント連携基盤＆Apple Payアダプタ (payment-event-ingestion) 詳細設計書

#### 1. 概要
- **対応仕様書**: [docs/spec/features/payment-event-ingestion.md](../../../spec/features/payment-event-ingestion.md)
- **目的**: 多様な決済プラットフォームからの支払いイベントを抽象化して処理できるアダプターアーキテクチャを設計し、その具体実装として Apple Pay アダプタを構築する。

---

#### 2. インターフェース＆データモデル設計

##### 2.1 共通正規化イベントモデル (`NormalizedExpenseEvent`)

```typescript
export interface NormalizedExpenseEvent {
  sourcePlatform: 'apple_pay' | 'google_pay' | 'paypay' | 'credit_card' | string;
  externalTransactionId?: string; // 外部取引ID（重複排除用）
  amount: number;                 // 金額（正の数値）
  currency: string;               // 通貨コード（'JPY'）
  merchantName?: string;          // 加盟店・店舗名
  spentAt: Date;                  // 決済日時
  paymentMethodDetail?: string;   // 例: 'iD (三井住友カード)'
  rawPayload: Record<string, unknown>; // 原本ペイロード
}
```

##### 2.2 決済イベントアダプターインターフェース (`PaymentEventAdapter`)

```typescript
export interface PaymentEventAdapter<TRaw = unknown> {
  readonly platformId: string;

  /** ペイロードを本アダプタで処理可能か判定 */
  canHandle(payload: unknown): boolean;

  /** プラットフォーム固有の生データを共通正規化モデルへ変換 */
  normalize(raw: TRaw): NormalizedExpenseEvent;
}
```

##### 2.3 インジェスチョン結果モデル (`PaymentIngestionResult`)

```typescript
export interface PaymentIngestionResult {
  status: 'created' | 'duplicate_skipped' | 'invalid_ignored';
  expenseId?: string;
  normalizedEvent: NormalizedExpenseEvent;
  message?: string;
}
```

---

#### 3. アダプター実装設計

##### 3.1 アダプターレジストリ (`PaymentEventAdapterRegistry`)
登録された複数アダプターを管理し、受信ペイロードを適切なアダプターに自動ディスパッチする。

```typescript
export class PaymentEventAdapterRegistry {
  private adapters = new Map<string, PaymentEventAdapter>();

  register(adapter: PaymentEventAdapter): void {
    this.adapters.set(adapter.platformId, adapter);
  }

  getAdapter(platformId: string): PaymentEventAdapter | undefined {
    return this.adapters.get(platformId);
  }

  findMatchingAdapter(payload: unknown): PaymentEventAdapter | undefined {
    for (const adapter of this.adapters.values()) {
      if (adapter.canHandle(payload)) {
        return adapter;
      }
    }
    return undefined;
  }
}
```

##### 3.2 Apple Pay アダプタ具体実装 (`ApplePayEventAdapter`)

iOS Shortcuts / App Intent 経由で渡されるペイロード形式:
```typescript
export interface ApplePayRawPayload {
  amount: number | string;
  merchant?: string;
  date?: string; // ISO 8601 または YYYY-MM-DD HH:mm:ss
  cardName?: string;
  transactionId?: string;
}
```

```typescript
export class ApplePayEventAdapter implements PaymentEventAdapter<ApplePayRawPayload> {
  readonly platformId = 'apple_pay';

  canHandle(payload: unknown): boolean {
    if (!payload || typeof payload !== 'object') return false;
    const p = payload as Record<string, unknown>;
    return p.source === 'apple_pay' || ('amount' in p && ('cardName' in p || 'merchant' in p));
  }

  normalize(raw: ApplePayRawPayload): NormalizedExpenseEvent {
    const parsedAmount = typeof raw.amount === 'string' ? parseFloat(raw.amount) : raw.amount;
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      throw new Error(`Invalid Apple Pay amount: ${raw.amount}`);
    }

    const spentAt = raw.date ? new Date(raw.date) : new Date();

    return {
      sourcePlatform: this.platformId,
      externalTransactionId: raw.transactionId,
      amount: Math.round(parsedAmount),
      currency: 'JPY',
      merchantName: raw.merchant?.trim(),
      spentAt: isNaN(spentAt.getTime()) ? new Date() : spentAt,
      paymentMethodDetail: raw.cardName ? `Apple Pay (${raw.cardName})` : 'Apple Pay',
      rawPayload: raw as Record<string, unknown>,
    };
  }
}
```

---

#### 4. インジェスチョンパイプライン設計 (`PaymentIngestionService`)

```text
[生ペイロード受信]
       │
       ▼
1. AdapterRegistry でアダプターを特定 & normalize 実行
       │
       ▼ (NormalizedExpenseEvent)
2. 重複チェック (DeduplicationCheck)
   ├─ 同一 externalTransactionId の存在確認
   └─ 近接時間(±3分)・同額・同店舗の既存支出確認
       │ (重複時はステータス 'duplicate_skipped' で終了)
       ▼
3. カテゴリ自動判定 (CategoryPredictor)
   └─ 店舗名キーワードマッチング (例: "セブン" -> "食費")
       │
       ▼
4. 支出データ永続化 (ExpenseRepository.add)
   └─ memo に決済手段や店舗名を付加
       │
       ▼
5. ローカルプッシュ通知発行 (NotificationService.notifyExpenseAdded)
   └─ タップ時にクイック編集モーダルを起動
```

---

#### 5. UIコンポーネント連携設計

- **画面構成および画面仕様 (draw.io)**: [docs/spec/screens.drawio](../../../spec/screens.drawio) （タブ: `外部決済連携設定`）
- **主要UIコンポーネント**:
  - `PaymentIntegrationsScreen`: 設定画面内の連携サービス一覧
  - `ApplePaySetupGuideModal`: オートメーション登録手順のステップウィザード
  - `QuickExpenseReviewModal`: 通知タップ時に表示されるハーフシートモーダル（金額・店舗・カテゴリ即時修正）

---

#### 6. テスト設計

##### 6.1 単体テスト (Unit Test)
- `ApplePayEventAdapter.normalize`:
  - 正常なペイロード（数値金額、文字列金額、店舗名あり/なし）が正確に正規化されること。
  - 金額が0以下やNaNの場合に例外を送出すること。
  - 不正な日付文字列が渡された場合にフォールバック（現在日時）で安全に処理されること。
- `PaymentIngestionService.process`:
  - 正常イベントが正しく `Expense` として永続化されること。
  - 同一取引IDの再受信時に重複スキップされること。
  - 近接時間（3分以内）の同額・同店舗決済が重複スキップされること。
  - 店舗名に応じたカテゴリが正しく推定されること。

##### 6.2 統合テスト
- イベント受信からローカルDB保存、通知発行までのパイプライン全体の疎通確認。

## 保存資料: apple-pay-background-sync / 仕様

移行元: `docs/spec/features/apple-pay-background-sync.md`。旧節番号とコード例を保持。

### 機能仕様書: Apple Pay バックグラウンド自動記録 (apple-pay-background-sync)

#### 1. 概要・背景
iOSのショートカットオートメーションにおいて、「URLを開く (`iris://add-expense`)」アクションは、画面ロック時やApple Pay決済直後のバックグラウンド状態ではiOSのセキュリティ制限によりブロックされ、アプリが前面に起動しない問題が発生する。
本仕様では、ショートカットの「URLの内容を取得」アクションを活用し、端末が画面ロック中であっても、Apple Pay決済時に完全バックグラウンドでAWS上のクラウドDB（DynamoDB）へ決済データを直接送信・自動記録する仕組みを規定する。

---

#### 2. ゴールと成果物
1. **画面ロック中の自動記録**: レジや改札でのApple Pay決済時に、画面ロック解除やアプリの前面起動を行うことなく、バックグラウンドで自動的に支出データがAWSへ保存される。
2. **超簡単ショートカット作成**: iOSショートカット上で複雑なJSONやヘッダー構築を必要とせず、1行のURL指定（GETリクエスト）で決済データを登録できるエンドポイントの提供。
3. **ローカルDB自動反映**: アプリ起動時にクラウド同期（Pull）が走り、バックグラウンド記録された支出が即座にローカルSQLiteに取り込まれ、ダッシュボードや支出履歴に表示される。
4. **プッシュ通知連携**: ショートカットの標準「通知を表示」アクションと連携し、決済直後に「Iris: [店舗名]で ¥[金額] を記録しました」と端末ロック画面へ通知可能にする。

---

#### 3. 機能要件

##### 3.1 バックエンド（AWS API Gateway & Lambda）仕様
- **エンドポイント**:
  - `GET /payment`
  - `POST /payment`
- **パラメータ要件**:
  - `user_id`（必須: クエリパラメータ または ヘッダー `x-user-id`）
  - `amount`（必須: クエリパラメータ または リクエストボディ。数値または¥記号付き文字列）
  - `merchant`（任意: 店舗名・加盟店名）
  - `spent_at`（任意: 決済日時。未指定時はサーバー現在日時 UTC/JST）
  - `source`（任意: 決済元。デフォルト: `apple_pay`）
- **処理ロジック**:
  - 店舗名からの簡易カテゴリ自動分類（例: セブン、ローソン、ファミマ、マクドナルド等は「食費」など）。
  - DynamoDB `EXPENSES_TABLE` への保存。
  - 成功時ステータス `200 OK` と保存結果JSONの返却。

##### 3.2 アプリ側（Flutter）仕様
- **起動時＆フォアグラウンド復帰時同期**: アプリのコールドスタート時およびバックグラウンドからのフォアグラウンド復帰時（`AppLifecycleState.resumed`）に、自動的にクラウドから差分Pull同期を実行し、バックグラウンド記録された支出を即座にローカルSQLiteへマージ。
- **Pull-to-Refresh（下に引っ張って更新）**: 日次支出ダッシュボード画面において、下方向へのスワイプで即座にクラウド同期を実行。
- **設定導線**: クラウド同期設定画面にて、ユーザー固有のショートカット用登録URLをワンタップでコピーできる導線を提供。

##### 3.3 iOSショートカットレシピ仕様
- **トリガー**: オートメーション「ウォレット（取引）」でカードを選択。「すぐに実行」を有効化。
- **アクション**:
  1. `ショートカットの入力` から `金額` を取得
  2. `ショートカットの入力` から `加盟店` を取得
  3. `URL` アクションで `https://<api-endpoint>/payment?user_id=<user_id>&amount=[金額]&merchant=[加盟店]` を作成
  4. `URLの内容を取得` アクション（GET）を実行
  5. （任意）`通知を表示` で「Iris: [加盟店]で ¥[金額] を記録しました」を表示

---

#### 4. 非機能要件
- **コスト厳守**: AWS完全サーバーレス（API Gateway + Lambda + DynamoDB）の常時無料枠内で動作し、追加費用は月0円（月500円以内を厳格遵守）。
- **可用性・耐障害性**: ネットワーク圏外時にショートカット側でエラーとなった場合でも、ショートカットの通知またはエラーハンドリングで検知可能とする。

## 保存資料: apple-pay-background-sync / 詳細設計

移行元: `docs/implementation/features/apple-pay-background-sync.md`。旧節番号とコード例を保持。

### 詳細設計書: Apple Pay バックグラウンド自動記録 (apple-pay-background-sync)

#### 1. アーキテクチャ概要
iOSの画面ロック中におけるURLスキーム（フォアグラウンド起動）制限を回避し、Apple Pay決済時に完全バックグラウンドで支出を記録するためのアーキテクチャ設計。

```
[Apple Pay決済] (店舗レジ/改札)
       │
       ▼ (画面ロック中)
[iOS ショートカット オートメーション]
       │
       ▼ (HTTP GET /payment?user_id=...&amount=...&merchant=...)
[AWS API Gateway (HTTP API)]
       │
       ▼
[AWS Lambda (Node.js 20.x)] ── (カテゴリ自動推定 & UUID採番)
       │
       ▼
[Amazon DynamoDB (iris_expenses_prod)]
       │
       ▼ (次回アプリ起動時 / バックグラウンドPull同期)
[Iris Flutter App (SQLite drift)]
```

---

#### 2. API設計（AWS Lambda / API Gateway）

##### 2.1 エンドポイント仕様
- **パス**: `/payment`
- **メソッド**: `GET` および `POST`（OPTIONS含む）
- **認証/識別**: `user_id`（クエリパラメータ または ヘッダー `x-user-id`）

##### 2.2 リクエストパラメータ
| パラメータ名 | 形式 | 必須 | 説明 | 例 |
| :--- | :--- | :--- | :--- | :--- |
| `user_id` | string | ○ | 端末固有のユーザーID | `d3b07384d113edec49eaa6238ad5ff00` |
| `amount` | number/string | ○ | 決済金額（数値またはカンマ/¥付き文字列） | `1200` または `¥1,200` |
| `merchant` | string | - | 店舗名・加盟店名（URLエンコード推奨） | `セブン-イレブン` |
| `spent_at` | ISO8601 | - | 決済日時（未指定時はサーバー現在日時） | `2026-10-04T12:00:00Z` |
| `payment_detail` | string | - | 決済手段詳細 | `Apple Pay` |

##### 2.3 カテゴリ自動判定ロジック (Lambda内)
Lambda内で簡易キーワードマッチングを行い、未分類にならないよう自動付与する：
- **食費 (`cat_food`)**: セブン, ローソン, ファミマ, マック, スターバックス, カフェ, ライフ, イオン, スーパー, すき家, 吉野家, 松屋, レストラン, 寿司
- **交通費 (`cat_transport`)**: ＪＲ, メトロ, 地下鉄, バス, タクシー, Ｓｕｉｃａ, ＰＡＳＭＯ, ＥＴＣ
- **日用品 (`cat_daily`)**: マツキヨ, ウエルシア, ドンキ, ダイソー, セリア, キャンドゥ, サンドラッグ
- **趣味・娯楽 (`cat_entertainment`)**: ＴＯＨＯ, シネマ, カラオケ, 映画, アニメイト, Ｓｔｅａｍ
- **その他 (`cat_other`)**: 上記に該当しない場合

##### 2.4 レスポンス仕様
`200 OK`:
```json
{
  "success": true,
  "message": "Payment recorded successfully",
  "expense": {
    "expense_id": "018d-...",
    "amount": 1200,
    "merchant_name": "セブン-イレブン",
    "category_id": "cat_food",
    "spent_at": "2026-10-04T12:00:00.000Z",
    "payment_method": "Apple Pay"
  }
}
```

---

#### 3. アプリ側連携設計 (Flutter)

##### 3.1 ユーザーID導線とワンタップURL生成
- `CloudSyncScreen`（クラウド同期設定画面）において、ショートカット作成用の「バックグラウンド自動記録URL」を1タップでクリップボードにコピーできるカードUIを追加。
  - コピーされるURL例:
    `https://tidcbcu3f9.execute-api.ap-northeast-1.amazonaws.com/payment?user_id=<USER_ID>&amount=`
- ユーザーはこのURLの後ろにショートカット変数（金額・店舗名）をつなげるだけで完成する。

##### 3.2 アプリ復帰時（resumed）自動同期設計
- `MainNavigationShell` に `WidgetsBindingObserver` を実装し、`didChangeAppLifecycleState` にて `AppLifecycleState.resumed`（アプリがフォアグラウンドに戻った時）を検知。
- 直前の同期時刻から最低5秒以上経過している場合、`cloudSyncStateProvider.notifier.syncNow()` を自動呼び出し。
- これにより、Apple Pay決済後にバックグラウンド起動中のIrisアプリを呼び出した瞬間に、直前の決済が即座に画面へ反映される。

##### 3.3 ダッシュボード Pull-to-Refresh 設計
- `DailyExpenseDashboardScreen` の `CustomScrollView` を `RefreshIndicator` でラップ。
- 画面を下に引っ張るジェスチャーで、手動同期 `cloudSyncStateProvider.notifier.syncNow()` を実行。

---

#### 4. iOSショートカット・オートメーション レシピ設計

##### 4.1 オートメーション設定
1. **トリガー**: 「ウォレット」（または「取引」）
   - カード: 決済に使用するクレジットカード / デビットカードを選択
   - カテゴリ: 「すべての取引」
2. **実行タイミング**:
   - **「すぐに実行」** にチェック
   - **「実行時に通知」** をON

##### 4.2 アクション手順
1. **テキスト アクション**:
   `https://tidcbcu3f9.execute-api.ap-northeast-1.amazonaws.com/payment?user_id=<USER_ID>&amount=`
   の末尾に、ショートカット入力の `金額`、さらに `&merchant=` の後ろに `加盟店` を挿入。
2. **URLの内容を取得 アクション**:
   - メソッド: `GET`
3. **通知を表示 アクション**:
   - 本文: `Iris: [加盟店] で ¥[金額] を自動記録しました`
