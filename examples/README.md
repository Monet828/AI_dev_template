# Example: expense-approval-tool

このディレクトリは、`AI_dev_template` の実際の生成コマンドを実行して作った、再現可能な小さな例。すべてのファイルは手作業で「それっぽく」書いたものではなく、実コマンドの実行結果か、そのまま素直に埋めた内容である。

## 課題の概要

ある小さな会社で、経費精算がExcelブック＋メール添付の運用になっており、承認・差し戻しのやり取りがメール本文に埋もれて追跡できない、という相談があったと仮定する。ツールを作る前に、「本当に解くべき課題は何か」をまず明確にしたい。

## 選択したprofileとpack

```bash
./scripts/setup/new-project.sh examples/expense-approval-tool/generated strategy
```

`strategy` profile（`evidence-first` + `problem-first`）を選んだ。実装にはまだ入らず、まず根拠を集めて（`evidence-first`）、何を解くべきかを定義する（`problem-first`）段階だったため。

## 生成された主要ファイル

`generated/` の中身は、上記コマンドをそのまま実行した結果そのもの（後から手で足したファイルはない）。

- `generated/.ai-dev-template.yml` — このプロジェクトが `template_version: 0.2.0`、`profile: strategy`、`evidence-first`/`problem-first` の両packで生成されたことの実際の記録
- `generated/AGENTS.md` — 共通ルール（`evidence-first`/`problem-first` pack適用によるappend済み）
- `generated/memory/evidence-log.md` — 調査の記録（下記参照）
- `generated/memory/problem-map.md` — 課題分解の記録（下記参照）
- `generated/memory/decisions.md` — 意思決定の記録（下記参照）
- `generated/memory/sessions/2026-07-28.md` — セッションログ（下記参照）

## session logの例

[`generated/memory/sessions/2026-07-28.md`](generated/memory/sessions/2026-07-28.md) は、`./scripts/setup/bootstrap.sh` が実際に作成したファイルに、そのセッションで起きたことをそのままの形式で書き込んだもの。Goal / Scope / Out of Scope / Stop Conditions を埋め、作業の結果 **製造部門への追加ヒアリング待ちで止まっている** ところまでを正直に記録してある。「今日はここまで完了しました」というきれいな完了例ではなく、途中で止まっている状態をそのまま見せている。

## decision recordの例

[`generated/memory/decisions.md`](generated/memory/decisions.md) には、「実装より先に問題設定を確定する」という決定を1件だけ記録した。理由・却下した代替案・影響範囲・再検討条件をセットで残している。一方、`problem-first` pack由来の「North Star」セクションはまだ空のままにしてある — このセッションではまだNorth Starが確定していない、という実際の状態を反映している。

## verification recordの例

[`verify-output.txt`](verify-output.txt) は `./scripts/loop/verify.sh` を `generated/` の中で実際に実行した、そのままの標準出力。この段階ではまだアプリコードを書いていないため、`pyproject.toml`/`package.json`/`Cargo.toml`/`go.mod` はどれも存在せず、ほぼ全項目が `[SKIP]` になっている。shell構文チェックだけは常に走り、`[PASS]` になっている。これは失敗ではなく、**まだ何も実装していない段階では検証すべきものがない、ということを正直に示している**——存在しないテストを「成功」扱いにするような誤魔化しはしていない。

[`doctor-output.json`](doctor-output.json) は `./scripts/setup/doctor.sh --json` の実際の出力。`"status":"ok"` で、生成直後は必須ファイルがすべて揃っている。

## 作業中断後に別エージェントが再開する例

[`resume-narrative.md`](resume-narrative.md) を参照。

## テンプレートなしの場合と比べた利点

テンプレートなしでゼロからチャットだけでこの作業を進めていたら、次のようなことが起きやすい。

- 「製造部門の回答待ちで止まっている」という状態が、チャットのスクロールの中に埋もれて次のセッションで見失われる
- 「なぜ実装より先に問題設定をやると決めたか」という理由が、後から参照できない
- 別の人（または別のAIエージェント）が引き継ぐときに、どこまで確定していて何が未確定かを、チャット全文を読まないと判断できない

このテンプレートでは、これらが `memory/sessions/`・`memory/decisions.md`・`memory/problem-map.md` というファイルとして残るため、Gitの差分として見え、レビューでき、次のセッションで機械的に読み込める。

## 既知の限界

- `doctor.sh`/`verify.sh` はファイルの存在確認・機械的なコマンド実行はするが、その中身が「本当に良い決定か」「本当に正しい課題設定か」までは判断しない。それは人間またはレビュー役のエージェント（`agents/reviewer.md`・`agents/verifier.md`）の仕事のまま。
- pack manifestは現状 `source` される平文シェルである（[`../SECURITY.md`](../SECURITY.md) 参照）。
- この例自体、`.ai-dev-template.yml` の `template_version` が将来のテンプレート更新で古くなる可能性がある。CIで定期的に再生成との差分を確認する運用を推奨する（今回のハードニングでは未実装、今後の課題）。
