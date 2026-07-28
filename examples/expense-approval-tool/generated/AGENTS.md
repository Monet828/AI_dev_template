# AGENTS.md

このファイルは、Claude Code、Codex、ChatGPT、その他AIエージェントがこのリポジトリで作業する際の共通ルールである。

このプロジェクトでは、AIを単なるコード生成器ではなく、設計・実装・レビュー・記録を支援する開発メンバーとして扱う。ただし、最終判断は人間が行う。

## 1. 基本方針

- 実装前に、目的・影響範囲・変更対象ファイル・リスクを確認する。
- 既存設計に反する変更をする場合は、実装前に理由と代替案を提示する。
- 大きな変更を一度に行わない。小さく分けて、差分を確認しやすくする。
- 不明点がある場合は、推測で実装しない。仮定を明示する。
- テスト・型・Lint・ビルドを軽視しない。
- 作業後には、必要に応じて `memory/current-state.md` または `memory/decisions.md` を更新する。
- `docs/` と `memory/` が矛盾する場合、原則として `docs/` を優先する。ただし現在の作業状況については `memory/current-state.md` を確認する。

## 2. ディレクトリ構成

ディレクトリの役割は `docs/project-structure.md` を唯一の正として扱う。

- 構成を変更する前に `docs/project-structure.md` を確認する。
- `src/` や `tests/` を編集する前に、関連する責務と影響範囲を確認する。
- `docs/` は正式仕様、`memory/` は作業記憶という原則を崩さない。

## 3. 作業開始時のルール

AIエージェントは作業開始時に、必要に応じて以下を確認する。

### 必須

1. `AGENTS.md`
2. `memory/current-state.md`
3. 関連する `docs/`
4. 関連する `src/` の既存実装

### 必要に応じて

5. `memory/decisions.md`
6. `memory/tasks.md`
7. 関連する `memory/sessions/`

そのうえで、以下を簡潔に整理してから作業する。

- 今回の目的
- 変更対象
- 影響範囲
- 想定リスク
- 確認すべきテスト
- 自律的に進めてよい範囲
- 止まるべき境界条件

## 4. 作業終了時のルール

作業後、AIエージェントは以下を確認する。

- 何を変更したか
- どのファイルを変更したか
- テスト・Lint・ビルド確認が必要か
- 新しい設計判断が発生したか
- 次回作業者に引き継ぐべきことがあるか
- 境界条件に到達したか

必要があれば、以下を更新する。

- `memory/current-state.md`
- `memory/decisions.md`
- `memory/tasks.md`
- `docs/`

ただし、作業ログを無制限に増やさない。不要になった一時情報は整理する。

## 5. リサーチ時のルール

AIが調査を行う場合、最初から主観的な評価・おすすめ・意味づけを混ぜない。

まずは以下を整理する。

- 一次情報
- 公式ドキュメント
- 事実
- 引用または要約
- 出典
- 不明点
- 確認が必要な点

重要度の判断、採用判断、意味づけは人間が行う。
AIが解釈や提案を求められた場合のみ、事実と意見を分けて提示する。

## 6. 設計時のルール

設計を行う場合は、以下を明示する。

- 解こうとしている問題
- 目的
- 制約
- 代替案
- 採用案
- 採用理由
- 却下した案
- 将来の変更余地
- 影響を受けるファイル

設計判断が長期的に有効な場合は、`memory/decisions.md` に記録する。正式な判断として残す場合は `docs/adr/` に昇格する。

## 7. 実装時のルール

実装では以下を守る。

- 既存の責務分離を壊さない。
- 不要な抽象化を追加しない。
- 既存コードのスタイルに合わせる。
- 変更範囲を小さく保つ。
- 暗黙の仕様変更をしない。
- ついでの大規模リファクタリングをしない。
- 影響範囲が広がる場合は、作業を止めて方針を確認する。

## 8. レビュー時のルール

レビューでは、実装者の意図を尊重しつつ、以下を確認する。

- バグの可能性
- 型安全性
- テスト不足
- セキュリティリスク
- 責務分離の崩れ
- 過剰実装
- パフォーマンス上の問題
- 既存仕様との矛盾
- ドキュメント更新漏れ

レビュー時は、単なる感想ではなく、根拠と修正案を提示する。

## 9. テスト・品質確認

変更後は、必要に応じて以下を確認する。

- 型チェック
- Lint
- Unit test
- Integration test
- Build
- 手動確認手順

テストが実行できない場合は、実行できなかった理由と、代替の確認方法を明記する。

`./scripts/loop/verify.sh` は、設定されているテスト/lint/buildを検出して実際に実行する。設定されていない項目は `[SKIP]` として明示され、成功扱いにはならない。

## 10. メモリ更新ルール

`memory/` は、AIエージェント間の文脈共有のために使う。

### `memory/current-state.md`

現在の作業状況を管理する。

含めるもの:

- Current Truth
- Active Work
- Next Actions
- Blockers / Risks
- Do Not Change
- Last Updated

更新する条件:

- 作業対象や優先順位が変わったとき
- 現在の真実が変わったとき
- ブロッカーや注意点が生じたとき
- 次回作業者が読まないと危険な情報が生じたとき

### `memory/decisions.md`

設計判断を記録する。

含めるもの:

- 日付
- 決定内容
- 理由
- 却下した案
- 影響範囲
- 将来の見直し条件

更新する条件:

- 実装や運用に影響する判断が発生したとき
- 次回以降も参照されると見込まれるとき
- 人間に承認された判断を残す必要があるとき

### `memory/tasks.md`

未完了タスクを管理する。

含めるもの:

- 優先度
- タスク内容
- 状態
- 関連ファイル
- 備考

### `memory/sessions/`

日ごとの作業ログを保存する。
ただし、長期的に有効な情報は `current-state.md`、`decisions.md`、または `docs/` に昇格させる。

含めるとよいもの:

- Goal
- Scope
- Out of Scope
- Stop Conditions
- Loop State
- Unresolved / Open Questions
- Resume From

## 11. 昇格条件

情報の置き場所は、次のルールで判断する。

### `memory/current-state.md` に置くもの

- 現在の作業状況
- 短期的な前提
- 未確定だが共有が必要な注意点
- 次回セッションで失うと困る文脈

### `memory/decisions.md` に置くもの

- 実装や運用に影響する判断
- 次回以降も再参照される判断
- 人間に承認された作業上の意思決定

### `docs/` または `docs/adr/` に昇格するもの

- 長期的に有効な仕様
- 正式な設計方針
- 運用ルール
- チームの正本として扱うべき知識
- 将来の作業者が `memory/` を見なくても参照できるべき内容

### 昇格しないもの

- 一時的な推測
- 未検証の仮説
- セッション中だけ有効なメモ
- すでに無効になった試行錯誤の履歴

## 12. Claude Code / Codex 併用ルール

Claude CodeとCodexを併用する場合、各ツールの内部記憶を正本にしない。
正本に近い情報は、以下に置く。

- 共通ルール: `AGENTS.md`
- 現在の状態: `memory/current-state.md`
- 設計判断: `memory/decisions.md`
- 正式仕様: `docs/`
- 実装本体: `src/`

Claude Code固有の設定は `.claude/` に置く。
Codex固有の設定は `.codex/` に置く。
ただし、プロジェクトの共通ルールは `AGENTS.md` を優先する。

## 13. Goal-Bounded Autonomy

合意された目的と範囲の中では、AIエージェントは細かい確認を挟まずに、自律的に作業を進めてよい。

基本方針:

- 目的、対象ファイル、期待成果、制約が十分に合意されているなら、その範囲では止まらずに進める。
- 些細な実装判断、調査順序、軽微な補助修正、検証の段取りは、都度確認を取らずに前進してよい。
- 途中で得た新情報により最短経路が変わっても、合意済みゴールの達成に資するなら、自律的に手順を調整してよい。

開始時に明確にする項目:

- Goal: 今回達成する成果物や状態
- Scope: 触ってよいファイル、機能、論点
- Out of Scope: 今回は触らない範囲
- Stop Conditions: 人間確認が必要になる境界条件

止まるべき境界条件:

- 目的そのものが曖昧で、複数の解釈で成果物が大きく変わるとき
- 合意済みの範囲を超える変更が必要になったとき
- 新しい仕様決定やアーキテクチャ判断が必要になったとき
- 破壊的変更、不可逆操作、大規模リファクタリングが必要になったとき
- 本番影響、認証、課金、権限、秘密情報に関わるとき
- 妥当な検証手段がなく、安全に完了とみなせないとき

推奨運用:

- 作業開始時に `memory/sessions/` へ Goal / Scope / Out of Scope / Stop Conditions を残す。
- 作業途中では、境界条件に到達したか、設計判断の昇格候補が出たかを記録する。
- 作業完了時には、達成内容と未解決点を分けて残す。

## 14. Loop Engineering v1

このテンプレートでは、最小の loop engineering として、実行状態、検証、再開可能性を明示する。

### Loop State

session には、必要に応じて以下を残す。

- `current`: 現在の実行状態
- `last_verified_at`: 最終検証時刻
- `step_budget`: このセッションで進める最大ステップ目安
- `retry_budget`: 再試行の最大回数目安

推奨 state:

- `goal_defined`
- `context_loaded`
- `plan_selected`
- `execute`
- `verify`
- `checkpoint`
- `done`
- `blocked`

### Budget の考え方

- `step_budget` は、無制限に探索や修正を繰り返さないための上限である。
- `retry_budget` は、同じ失敗を繰り返す前に停止して再判断するための上限である。
- 厳密な数値最適化は不要だが、長い作業では空欄にしないほうがよい。

### Verifier の扱い

- 完了とみなす前に、少なくとも一度は verifier 観点で見直す。
- 小さな作業でも、何を確認し、何を未確認のまま残したかを明示する。
- テストを実行できなかった場合は、未確認点として残す。

### Resume の扱い

- 作業を止めるとき、特に `blocked` で終えるときは `Resume From` を残す。
- `Resume From` には次の state、必要な文脈、停止理由を書く。
- 次回作業者は、最初に `Resume From` を見てから再開する。

### 未確定事項の扱い

- 未確定事項や open question は、頭の中だけに残さず session に書く。
- 小さい未確定事項でも、次の判断に影響するなら `Unresolved / Open Questions` に残す。
- 今回解かないが次回見落とすと危険な論点は、必要に応じて `memory/current-state.md` や `memory/tasks.md` にも昇格する。

## 15. 標準コマンド

利用可能なら、以下を標準コマンドとする。

- `./install.sh`
- `./run.sh`
- `./scripts/setup/bootstrap.sh`
- `./scripts/setup/doctor.sh`
- `./scripts/hooks/pre-task.sh`
- `./scripts/hooks/post-task.sh`
- `./scripts/hooks/stop.sh`
- `./scripts/hooks/save-memory.sh`
- `./scripts/loop/verify.sh`（実チェック。設定されているテスト/lint/buildを検出して実行し、`[PASS]/[SKIP]/[FAIL]` を返す）
- `./scripts/loop/record-verification.sh`（自己申告ログ。`verify.sh` を実行した後、その結果と所感を `memory/sessions/` に記録する）
- `./scripts/loop/resume.sh`

これらが未実装の場合は、追加時にこの節を更新する。

## 16. 禁止事項

AIエージェントは以下を行わない。

- 明示されていない大規模リファクタリング
- 不要なファイル大量生成
- 仕様の暗黙変更
- テストを無視した実装
- `docs/` と矛盾する変更
- セキュリティ上危険なショートカット
- 秘密情報のログ出力
- 一時的な推測を正式仕様として記録すること

## 17. 判断に迷った場合

判断に迷った場合は、以下の形式で整理する。

1. 現在わかっている事実
2. 不明点
3. 考えられる選択肢
4. 各選択肢のメリット・デメリット
5. 推奨案
6. 人間に確認すべき点

ただし、リサーチ段階では推奨案を急がず、まず一次情報と事実を整理する。


## Evidence-First Research Addon

このプロジェクトでは、調査や比較を行うとき、最初から主観的な評価やおすすめを混ぜない。

基本方針:

- 最初に一次情報、公式情報、観測事実を整理する
- 出典、日付、引用または要約を `memory/evidence-log.md` に残す
- 事実と解釈を分けて書く
- 不明点と確認が必要な点を明示する

推奨運用:

- `memory/evidence-log.md` に source type、source、date、fact、quote or summary、open questions を残す
- `scripts/workflows/evidence-first.sh` を使って調査 checkpoint を残す
- 調査途中の仮説は正式仕様として昇格させず、まず evidence として整理する

停止条件:

- 主張の根拠となる source が示せない
- source date が不明で、鮮度が重要な論点を安全に扱えない
- 事実と解釈が混ざっていて、あとから検証できない

比較や提案を求められた場合のみ、evidence の後段として解釈を書く。


## Problem-First Development Addon

このプロジェクトでは、実装を急ぐ前に、まず解くべき問題を明確にする。

基本方針:

- コンセプト、目的、最大問題を先に言語化する
- 実装に入る前に、解くべき一番大きな問題を 1 つだけ `memory/decisions.md` に North Star として定義する
- 大問題を小問題へ分解する
- その時点で最重要の小問題を 1 つだけ選ぶ
- 進捗は、書いた量ではなく、潰した問題で評価する

推奨運用:

- `docs/templates/PROBLEM-BRIEF.md` に長期の problem framing を置く
- `memory/problem-map.md` に current problem decomposition を置く
- `memory/tasks.md` には必要条件ツリーを置き、各 sub-goal に North Star との traceability を書く
- `memory/sessions/` には、その日に潰す current subproblem と unresolved questions を置く
- `scripts/workflows/problem-framing.sh` を使って問題設定の checkpoint を残す

ルール:

- `memory/decisions.md` に North Star が定義・承認されるまで `assets/patterns/` を参照しない
- issue が確定した後にだけ、`assets/patterns/` の `When To Apply / When Not To Apply` で適合性を確認する
- 各 sub-goal は 1 loop として進め、完了を主張する前に verifier で「本当に効いたか」を検証する
- verifier では「この枝を全部潰したら本当に North Star が解けるか」を再合成の観点で点検する
- 効いた解法は `assets/patterns/` に新規追加するか、既存 pattern の `Pitfalls / Learnings` を更新する
