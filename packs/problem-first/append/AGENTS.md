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
