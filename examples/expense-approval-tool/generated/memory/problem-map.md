# Problem Map

## Current Truth

- 経費精算は部門ごとにExcelブック＋メールのやり取りで運用されており、承認・差し戻しの履歴が構造化されていない

## Goal

- 経理・各部門双方の手間を増やさずに、承認状況と差し戻し理由を追跡可能にする

## Biggest Problem

- 差し戻し理由が構造化されておらず、同じ指摘を繰り返す非効率が発生している

## North Star

- （未確定 — 製造部門への追加ヒアリング回答待ちのため、このセッションでは仮置きのまま次回セッションに持ち越す）

## Necessary Conditions

- [ ] 差し戻し理由が申請者・経理の双方から後から参照できる
- [ ] 部門間の運用差異（製造部門はなぜ差し戻しが少ないのか）の原因を特定できている
- [ ] 経理側の追加作業負荷を増やさない

## Subproblems

- [ ] 差し戻し理由の構造化（定型化するか自由記述のままにするか）
- [ ] 承認フローの通知手段（メール継続か、別チャネルにするか）
- [ ] 既存Excel運用からの移行コスト

## Current Subproblem

- 差し戻し理由の構造化（定型化するか自由記述のままにするか）

## Traceability

- This subproblem satisfies: Necessary Condition「差し戻し理由が申請者・経理の双方から後から参照できる」

## Why This One Now

- ヒアリングで最も強く言及された不満点であり、他の枝より優先度が高いため

## Evidence / Findings

- `memory/evidence-log.md` の Facts を参照

## Unresolved / Open Questions

- 製造部門への追加ヒアリング回答待ち（このセッションのブロッカー）

## Next Subproblem Candidates

- 承認フローの通知手段（メール継続か、別チャネルにするか）

## Re-synthesis Check

- If these branches are solved, does North Star really become solvable?
- 差し戻し理由の構造化だけで「経理側の追加作業負荷を増やさない」条件まで満たせるかは、まだ検証できていない
