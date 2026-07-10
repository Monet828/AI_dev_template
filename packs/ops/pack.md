# pack: ops

opt-in の運用/保守パック。`scripts/setup/scaffold.sh` が注入する（merge/append 方式）。

配置先:
- `README.md` / `graduation-checklist.md` → `packs/ops/`（そのまま参照物として）
- `maintenance-runbook.template.md` → 雛形はパックに残す。
  記入済み runbook はプロジェクト固有状態なので `memory/ops/<サービス>.md` に作り、
  `memory/tasks.md` から参照する。

要旨: 出力を「プロト（使い捨て・運用ゼロ）」と「昇格（人間オーナー必須の本運用）」の
2 tier に分け、間に卒業ゲートを 1 枚置く。2 tier の混同を防ぐのが目的。
