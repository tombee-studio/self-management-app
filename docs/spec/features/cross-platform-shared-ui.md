# 共通UI・マルチデバイス対応 設計

- **バージョン**: v2.0.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

対応要求: [REQ](../../req/features/cross-platform-shared-ui.md)。設計の正本は本書。

## ドメイン境界・モデル

分類: **PresentationPolicyの技術的能力（業務集約なし）**。[共通アーキテクチャ](../architecture.md)と[ADR-0002](../../adr/0002-domain-contract-design.md)のDDD方針と[ADR-0003](../../adr/0003-cloud-api-only.md)のAWS配置に従う。全契約はv2.0.0。既存REQの業務範囲・AC番号を維持する。

| モデル | 所有・構成・制約 |
| :--- | :--- |
| WindowContext / LayoutDecision（値） | 論理幅・高さ・Insets → Compact/Medium/Expanded、ナビ方式、フォーム配置 |
| NavigationState / ExpenseDraft（UI状態） | 選択タブ・日付・履歴条件・入力。業務集約と分離 |

### 不変条件・依存方向

- 幅/OSが変わっても金額・カテゴリ・期間の業務ルールを変えない。
- レイアウトを選択する純粋関数はDB・通知・ネットワークを呼ばない。
- 回転・リサイズで同じドラフトIDと編集版を保持し、保存はMAN/BUD等の契約へ委譲。

LayoutPolicy.resolve、NavigationController、DraftStorePort、FeatureApplicationPorts。Flutter/Riverpodはpresentation adapterであり純粋Policyの依存先にしない。

### 公開契約

契約の成功・失敗・版・トランザクション・再試行の共通意味は[共通規則](../architecture.md#5-契約の共通規則)。Operationの引数型は上の値型/DTOとSPEC-01の項目定義を使い、DynamoDB項目型を公開しない。QueryのsnapshotIdとVersionは互換ではない。本機能の純粋Policy/ビルド契約をHTTPで公開しない。

<a id="ui-c01"></a>
#### UI-C01: ResolveLayout

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ResolveLayout{width,height,safeInsets,keyboardInsets} → Result<LayoutDecision>` |
| 事前条件 | 有限の正の幅/高さ、Insets>=0 |
| 成功後の保証・変更範囲 | 600未満Compact/下部/Sheet、600〜839 Medium/Rail/Dialog、840以上Expanded/Side/2ペイン。DB副作用なし |
| 失敗 | ValidationFailed |
| 冪等性・再試行 | 同入力は同じ決定。OS名は分岐条件に使わない |
| 対応REQ | [AC-01](../../req/features/cross-platform-shared-ui.md#ac-01), [AC-03](../../req/features/cross-platform-shared-ui.md#ac-03), [AC-04](../../req/features/cross-platform-shared-ui.md#ac-04) |

<a id="ui-c02"></a>
#### UI-C02: ReflowDraft

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `ReflowDraft{draftId,state,newWindowContext} → Result<PresentationState>` |
| 事前条件 | 有効draftIdと状態、計算済みLayoutDecision |
| 成功後の保証・変更範囲 | 選択日・表示月・金額・メモ・expectedVersionを維持。レイアウトだけ変更 |
| 失敗 | ValidationFailed |
| 冪等性・再試行 | 同じリサイズ通知でもドラフト再生成・保存なし |
| 対応REQ | [AC-02](../../req/features/cross-platform-shared-ui.md#ac-02), [AC-04](../../req/features/cross-platform-shared-ui.md#ac-04) |

<a id="ui-c03"></a>
#### UI-C03: HandleNavigationIntent

| 契約要素 | 定義 |
| :--- | :--- |
| 入出力 | `HandleNavigationIntent{intent,focusState,draftState} → NavigationDecision` |
| 事前条件 | intentはタブ/⌘N/⌘矢印/Esc。編集未保存ならMAN契約で確認 |
| 成功後の保証・変更範囲 | 文字入力中の矢印は日移動しない。背景/Done/タブでフォーカス解除。Escは破棄確認に従う |
| 失敗 | なし。ドメイン保存の失敗は委譲先Resultを表示 |
| 冪等性・再試行 | 同状態で同入力は同じ遷移判断、二重保存しない |
| 対応REQ | [AC-05](../../req/features/cross-platform-shared-ui.md#ac-05), [AC-06](../../req/features/cross-platform-shared-ui.md#ac-06) |

## SPEC-01: 共通UI・サイズ区分

Flutter/Dart、Riverpod、Materialテーマを採用し、iOS/AndroidのUI・計算ロジックを共通化する。ネイティブ差分は通知・リンク・保存パスのアダプタへ限定する。日本語・JPY表示。最低OS版はiOS 16・Android 12。ビルド設定と実機検証対象をこの要求へ合わせる。

| 論理ピクセル幅 | ナビゲーション | 日次画面 | 支出フォーム |
| :--- | :--- | :--- | :--- |
| <600 | 下部タブ | 縦スクロール | BottomSheet |
| 600以上840未満 | NavigationRail | サマリー・内訳を横並び、明細は下 | 中央Dialog |
| 840以上 | ラベル付きサイドナビ | 左サマリー・右明細/編集の2ペイン | 新規はDialog、既存は右ペイン |

左ペインは幅の40%（最大380）、右は残り。Dialog最大幅460、利用可能高さに収め、内容はスクロール可能とする。幅はMediaQueryの現在幅で判定する。OS・端末名・縦横ラベルを閾値判定に使わない。900単独のナビ切替方式は採用しない。

## SPEC-02: 構成・状態

Flutter widgets → NavigationController + 純粋LayoutPolicy。RiverpodはComposition RootでDraftStoreと各Feature Handlerを注入し、DomainをFlutterへ依存させない。


⌘Nは手動支出追加、⌘←/→は日次の日付変更、Escはフォームを閉じる（未保存時は破棄確認）。テキスト入力中は矢印ショートカットを無効化する。背景・Done・タブ切替でFocusを解除する。画面幅320、600、840、900と各境界直前の表示を検証する。

## SPEC-03: エラー・理由

キーボードが表示されても保存・閉じるへスクロールして到達できること。大きな文字・金額で固定高さからはみ出さないようFlexible/Wrap/Scrollを使う。画面サイズによる表示だけを変え、金額や日付の業務ルールをOSごとに変えない。600/840の共通関数に集約し、ナビ・画面・図で異なる閾値を持たせない。

## REQ対応・検証入口

- [cross-platform-shared-ui/AC-01](../../req/features/cross-platform-shared-ui.md#ac-01): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-02](../../req/features/cross-platform-shared-ui.md#ac-02): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-03](../../req/features/cross-platform-shared-ui.md#ac-03): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-04](../../req/features/cross-platform-shared-ui.md#ac-04): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-05](../../req/features/cross-platform-shared-ui.md#ac-05): 本書のSPEC-01〜03で具体化。
- [cross-platform-shared-ui/AC-06](../../req/features/cross-platform-shared-ui.md#ac-06): 本書のSPEC-01〜03で具体化。

検証計画は[VERIFY一覧](../../verification/VERIFY.md)。コードが本設計に追従しているかは[実装差分](../../STATUS.md)で管理し、文書レビューのPASSを実装済み・検証済みと扱わない。

## 契約検証・実装への移行

[機能別検証計画](../../verification/features/cross-platform-shared-ui.md)のTC-R3-CTで公開契約ごとの前提違反・成功保証・不変条件・失敗時副作用・再試行を検証する。既存SPEC-01〜03の業務/画面条件を契約の詳細規則として維持する。既存実装と途中の変更は移行元であり、本設計に適合済みとは扱わない。

## API版3への適用

保存・参照の配置、requestId、通信失敗、Undo期限は[共通アーキテクチャ](../architecture.md)に従う。表示・ドラフトはメモリのみで、端末内DBへの保存・参照・移行を設計に含めない。HTTP公開形式は[契約一覧](../contracts/README.md)。
