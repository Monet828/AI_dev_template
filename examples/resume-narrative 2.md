# 中断後、別のエージェントが再開する例

前提: `generated/memory/sessions/2026-07-28.md` のセッションは、製造部門への追加ヒアリング回答待ちで止まっている。数日後、担当者から回答が来て、**最初のセッションとは別のAIエージェント**（あるいは同じClaude Codeでも、コンテキストが失われた新しいセッション）がこの作業を引き継ぐとする。

## 1. 新しいエージェントがまずやること

```bash
cd generated
./scripts/loop/resume.sh
```

`resume.sh` は `memory/current-state.md` と、最新のセッションファイル（`memory/sessions/2026-07-28.md`）の `Loop State` セクションと `Resume From` セクションを抜き出して表示する。実行すると、次が画面に出る。

```
== Resume Loop ==
Read in this order:
1. memory/current-state.md
2. latest session file
3. Resume From
...
## Loop State

- current: execute
- last_verified_at:
- step_budget: 6
- retry_budget: 2

## Resume From

- next_state: plan_selected
- required_context: `memory/problem-map.md` の現状仮説、`memory/evidence-log.md` の Facts、このログの Unresolved / Open Questions
- blocking_reason: 製造部門への追加ヒアリング回答待ち（本人が出張中のため今週末までかかる見込み）
```

新しいエージェントは、チャット履歴を一切持っていなくても、この出力だけで次のことが分かる。

- 何を目指していたか（`memory/current-state.md` と `memory/problem-map.md` の Goal）
- どこまで進んでいたか（`current: execute`、Necessary Conditionsのチェック状況）
- なぜ止まっていたか（製造部門の回答待ち）
- 次に何をすべきか（`next_state: plan_selected` — 回答を`memory/evidence-log.md`に追記し、`memory/problem-map.md`のNorth Starを確定する）

## 2. 引き継いだ後の実際の作業

新しいエージェントは、`required_context` に書かれた3つのファイルを読んでから、次のように進める。

1. 製造部門の回答を `memory/evidence-log.md` の `Facts` に追記する
2. `memory/problem-map.md` の `North Star` を確定し、`Unresolved / Open Questions` から該当項目を消す
3. `memory/decisions.md` に、North Starを確定したことを新しい決定として記録する
4. セッションファイルの `Loop State` を更新し、`Resume From` を次の段階（実装フェーズへの移行判断）向けに書き換える

## 3. テンプレートがなかった場合との違い

チャットの記憶だけに頼っていた場合、この引き継ぎは次のようになりがちである。

- 「前回何が課題で止まっていたか」を、長いチャット履歴を遡って探す必要がある
- 遡って探しても、「製造部門の回答待ち」という一言が明示的に書かれていなければ、見落として同じ質問を繰り返してしまう
- 別のエージェント（別のセッション、別のツール）が引き継ぐ場合は、そもそも前のチャット履歴自体にアクセスできない

`resume.sh` は、これを **ファイルの中の決まったセクションを読むだけ** の機械的な操作に変えている。エージェントの種類や、前回と同じチャットセッションかどうかに依存しない。
