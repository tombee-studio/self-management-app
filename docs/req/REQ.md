# Layer 1: 要求インデックス

- **バージョン**: v0.3.0
- **ステータス**: done
- **更新日**: 2026-11-01（JST）

## プロダクトと対象範囲

iris 支出管理（パッケージ: `iris_app`）。個人が日々の支出を記録・振り返り、予算を管理する。ownerの2026-11-01の回答により、既存資料の全9機能を今回の対象とする。基本支出管理の依頼は[Issue #1](https://github.com/tombee-studio/self-management-app/issues/1)。

## 要求一覧

| 機能 | 正本 | 責務 | 状態 |
| :--- | :--- | :--- | :--- |
| 日次支出ダッシュボード | [daily-expense-dashboard](features/daily-expense-dashboard.md) | 選択日の支出総額・カテゴリ内訳・明細を把握し、使いすぎに気付けるようにする | done |
| 支出の手動登録・編集・削除 | [manual-expense-crud](features/manual-expense-crud.md) | 日々の支出を記録し、誤記や不要な明細を修正できるようにする | done |
| 支出履歴・過去一覧 | [expense-history-list](features/expense-history-list.md) | 過去の支出を日付や条件から探し、振り返れるようにする | done |
| 予算設定・管理 | [budget-management](features/budget-management.md) | 設定した家計期間の残予算・日次目安・支出ペースを把握する | done |
| カテゴリマスター管理 | [category-master-management](features/category-master-management.md) | 生活に合わせて分類し、カテゴリ整理で既存支出を失わないようにする | done |
| 外部決済イベント連携 | [payment-event-ingestion](features/payment-event-ingestion.md) | Apple Pay等の決済データを取り込み、重複・記録漏れを減らす | done |
| クラウド同期 | [aws-cloud-database-sync](features/aws-cloud-database-sync.md) | ローカル操作を保ちながらクラウドへ支出・カテゴリ・予算を保存し、端末間で整合させる | done |
| 共通UI・マルチデバイス対応 | [cross-platform-shared-ui](features/cross-platform-shared-ui.md) | スマートフォン・タブレット間で一貫した主要操作を提供する | done |
| アプリアイコン・ブランディング | [app-icon-branding](features/app-icon-branding.md) | ホーム画面で支出管理アプリを識別しやすくする | done |

## 共通定義

- 支出は日本円の整数1〜99,999,999円。返金・負額支出・多通貨換算は対象外。
- 日次・履歴の月次集計は端末ローカルの暦日・暦月。予算だけは設定開始日を基準とした家計期間。両者を同じ月間実績と呼ばない。
- 店舗名はローカルではメモに含め、外部イベントの店舗名をメモ初期値に使う。記録元（manual/apple_pay）と支払い方法（cash等）は別項目。
- ローカル保存・オフライン参照を優先し、クラウド通信は同期設定に従う。第三者向け多人数公開サービスは対象外。
- 受け入れ基準の識別子は`機能名/AC-xx`。各機能の既存AC-01〜03を維持し、追加条件は後続番号で管理する。

## 集約先と境界

登録・変更は手動支出、日次の表示はダッシュボード、期間検索は履歴へ集約する。カテゴリのマスター編集と予算配分は独立した責務として分ける。削除同期は同期、背景決済APIは外部決済、画面サイズ対応は共通UIへ集約し、追加時期・画面差だけで機能を増やさない。旧14項目の対応は[SPEC](../spec/SPEC.md)を参照する。

## レビューと工程

[REQ運用](../operations/01_REQ.md)で本書と全機能をレビューし、全件done後にSPECを同期する。実装・検証の完了判定は[VERIFY](../verification/VERIFY.md)で行う。[過去資料](../archive/2026-11-01/README.md)は正本・ゲート対象に含めない。横断判断の記録は[ADR](../adr/ADR.md)に従う。

## 関連ADR

[ADR-0001: 全9機能の対象範囲](../adr/0001-nine-feature-scope.md)に従う。文書確定と実装・検証完了は別に判定する。
