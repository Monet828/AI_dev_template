## Evidence-First Research Addon

このプロジェクトでは、調査や比較を行うとき、最初から主観的な評価やおすすめを混ぜない。

基本方針:

- 最初に一次情報、公式情報、観測事実を整理する
- 出典、日付、引用または要約を `memory/evidence-log.md` に残す
- 事実と解釈を分けて書く
- 不明点と確認が必要な点を明示する

観測値を前提に置く作業（過去ログ・メトリクスの集計、DB の件数・棚卸しを根拠に
するもの）は、**起票前に Evidence Card を埋める**。埋まらない項目があるなら、
その作業はまだ着手できる状態にない。テンプレートは `docs/templates/evidence-card.md`。

- 「件数」が raw / logical / effective のどれを指すかを必ず定義する。ここが最も
  事故りやすい
- その主張を**反証する最も安い方法**と、**反証されたら作業をどう扱うか**を先に書く
- **反証は失敗ではない。** 誤った前提を潰したこと自体が成果であり、そこで打ち切る。
  反証された claim から follow-up の修正タスクを作らない

推奨運用:

- `memory/evidence-log.md` に source type、source、date、fact、quote or summary、open questions を残す
- `scripts/workflows/evidence-first.sh` を使って調査 checkpoint を残す
- 調査途中の仮説は正式仕様として昇格させず、まず evidence として整理する

停止条件:

- 主張の根拠となる source が示せない
- source date が不明で、鮮度が重要な論点を安全に扱えない
- 事実と解釈が混ざっていて、あとから検証できない

比較や提案を求められた場合のみ、evidence の後段として解釈を書く。
