## Understand-First Development Addon

このプロジェクトでは、既存コードや既存仕様を触る前に、まず対象を理解する。

基本方針:

- 既存コードを変更する前に、関連する実装、`docs/`、`memory/` を読む
- 実装に入る前に、対象領域の責務、入出力、依存関係、影響範囲を言語化する
- 理解した内容は `memory/understanding-map.md` に残し、chat のみに留めない
- 未解決事項がある場合は `memory/sessions/` の `Unresolved / Open Questions` にも残す

推奨運用:

- `memory/understanding-map.md` に対象、読んだファイル、現状挙動、責務、依存関係、リスク、unknowns を残す
- `scripts/workflows/understand-first.sh` を使って理解 checkpoint を残す
- 大きい変更では `Safe change boundary` を書いてから実装へ進む

停止条件:

- 対象責務を説明できない
- 主な入口と出口が分からない
- 影響範囲の仮説が持てない
- 未解決事項が多く、安全に変更できる境界が引けない

軽微な修正では簡略化してよいが、`Files read` と `Unknowns` を空で進めない。
