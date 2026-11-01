# 共通UI・マルチデバイス対応 検証計画

- **バージョン**: v1.0.0
- **ステータス**: done
- **計画日**: 2026-11-01（JST）

対応: [REQ](../../req/features/cross-platform-shared-ui.md) / [SPEC](../../spec/features/cross-platform-shared-ui.md)。計画確定は検証済みを意味しない。結果は実装後に`docs/verification/results/cross-platform-shared-ui.md`へ記録する。

## 範囲・前提・方法

全ACを必須ケースに含む。[共通検証条件](../VERIFY.md)の固定時計・タイムゾーン・DB・ネットワーク代替を使う。単体は純粋ロジック、結合は実SQLiteとRepository、Widgetは操作と表示、APIは隔離テスト環境、実機はiOS/Androidで実施する。

ケースごとにDB・outbox・通知履歴を初期化する。期待値に記した全条件を満たせばPASS、相違はFAIL、環境未準備は未実施とし、必須のFAIL/未実施があれば機能完了にしない。全9機能を対象とするため、対応OS・指定範囲の検証を省略しない。外部の新決済サービス、多人公開運用は要求対象外。

## ケース

| ケースID | 対応REQ | 対応SPEC | 入力・前提 | 手順 | 期待結果・合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| cross-platform-shared-ui/TC-01 | [AC-01](../../req/features/cross-platform-shared-ui.md#ac-01) | SPEC-01〜03 | iOS/Android、幅320/600/900、縦横、キーボードあり | 主要4画面とフォームを操作 | 主要操作にスクロールで到達し、レイアウト例外・欠けなし | Widget/実機 |
| cross-platform-shared-ui/TC-02 | [AC-02](../../req/features/cross-platform-shared-ui.md#ac-02) | SPEC-01〜03 | 選択日11/2、履歴月10月、入力金額1280 | 回転と600/840境界を跨ぐリサイズ | 選択日・表示月・入力金額を保持 | Widget |
| cross-platform-shared-ui/TC-03 | [AC-03](../../req/features/cross-platform-shared-ui.md#ac-03) | SPEC-01〜03 | 同一データと日本語設定のiOS/Android | 登録・編集・集計・予算を同じ手順で実行 | DB内容・集計値・操作結果が一致 | E2E |
| cross-platform-shared-ui/TC-04 | [AC-04](../../req/features/cross-platform-shared-ui.md#ac-04) | SPEC-01〜03 | 幅599/600/839/840 | ナビとフォームを表示 | 順に下部/Rail/Rail/サイドナビ、フォームはSheet/Dialog/Dialog/Dialog（編集は2ペイン） | Widget |
| cross-platform-shared-ui/TC-05 | [AC-05](../../req/features/cross-platform-shared-ui.md#ac-05) | SPEC-01〜03 | SafeArea inset、キーボードviewInsets、予算入力中 | 背景/Done/タブで操作 | フォーカス解除、保存と閉じるが隠れず操作可能 | Widget/実機 |
| cross-platform-shared-ui/TC-06 | [AC-06](../../req/features/cross-platform-shared-ui.md#ac-06) | SPEC-01〜03 | 幅840、選択日、フォーム未保存、文字入力中 | ⌘N・⌘←/→・Escを操作 | 追加/日移動/破棄確認、文字入力中の矢印は日付を変えない。右ペインに編集 | Widget/実機 |

## 実行・証跡

単体・結合ケースは必要なテストを実装し`flutter test test/unit`、Widgetケースは`flutter test test/widget test/widget_test.dart`で実行する。新設するテストのパスと実行対象は結果へ記録する。現存テストの成功だけで本表全件を実施済みにしない。API・E2E・実機は表の手順を実施し、要求データと応答、前後のDB状態、画面・通知の証跡を保存する。

結果には対象コミット、実施日時（JSTと必要なUTC）、Flutter/Dart・OS・端末/画面幅・DB版、実測結果、判定、証跡へのリンク、不具合・再検証を記載する。端末内の実データや既存クラウドへ検証用明細を送らず、専用テスト環境を使う。

## ドメイン・公開契約の検証（ARCH-01）

[共通アーキテクチャ](../../spec/architecture.md)と機能書の契約を対象とする。既存TC-01以降を残し、以下のTC-CTを追加する。文書での契約定義・スキーマ例の検証をprovider/consumer実装の合格と混同しない。

基準fixture: 幅320/599/600/839/840/900、負幅、入力1280のdraftとexpectedVersion、回転・キーボード・文字編集中の矢印を用意。

| ケースID | 対応契約・要求 | 入力/前提・手順 | 合否基準 | 方法 |
| :--- | :--- | :--- | :--- | :--- |
| cross-platform-shared-ui/TC-CT-01 | [UI-C01](../../spec/features/cross-platform-shared-ui.md#ui-c01)、REQ/ARCH-01、AC-01/03/04 | 上のfixtureからResolveLayoutの正常入力と、事前条件「有限の正の幅/高さ、Insets>=0」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「600未満Compact/下部/Sheet、600〜839 Medium/Rail/Dialog、840以上Expanded/Side/2ペイン。DB副作用なし」を実値/件数で確認。失敗はValidationFailedと一致し、未commitなら状態/版/Outbox不変。再試行は「同入力は同じ決定。OS名は分岐条件に使わない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| cross-platform-shared-ui/TC-CT-02 | [UI-C02](../../spec/features/cross-platform-shared-ui.md#ui-c02)、REQ/ARCH-01、AC-02/04 | 上のfixtureからReflowDraftの正常入力と、事前条件「有効draftIdと状態、計算済みLayoutDecision」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「選択日・表示月・金額・メモ・expectedVersionを維持。レイアウトだけ変更」を実値/件数で確認。失敗はValidationFailedと一致し、未commitなら状態/版/Outbox不変。再試行は「同じリサイズ通知でもドラフト再生成・保存なし」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |
| cross-platform-shared-ui/TC-CT-03 | [UI-C03](../../spec/features/cross-platform-shared-ui.md#ui-c03)、REQ/ARCH-01、AC-05/06 | 上のfixtureからHandleNavigationIntentの正常入力と、事前条件「intentはタブ/⌘N/⌘矢印/Esc。編集未保存ならMAN契約で確認」を1項目ずつ破る入力を生成。成功→同要求再送→stale版/不正入力→失敗注入の順で実行。非該当の版・書込条件はQuery/純粋Policyの副作用ゼロで確認 | 成功保証「文字入力中の矢印は日移動しない。背景/Done/タブでフォーカス解除。Escは破棄確認に従う」を実値/件数で確認。失敗はなし。ドメイン保存の失敗は委譲先Resultを表示と一致し、未commitなら状態/版/Outbox不変。再試行は「同状態で同入力は同じ遷移判断、二重保存しない」どおり | Domain単体＋Application/provider契約テスト。HTTP境界がある操作は共通fixtureでconsumerも検証 |

Portのfakeと本番adapterへ同じcontract suiteを適用する。Queryは業務DB・版・Outboxの変更回数0、Commandはcommit後に限るイベント発行を監視する。同期は部分commit契約に従いACK済みだけが残り、cursor/lastSuccessは成功条件を満たした時だけ更新されることを確認する。UI・アイコンではDB参加を要求せず、純粋Policy/ビルド契約と実機証跡を確認する。

追加契約テストは今回未実施。途中実装の既存テスト結果を新契約への合格証跡として流用しない。
