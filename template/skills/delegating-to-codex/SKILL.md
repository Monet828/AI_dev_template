---
name: delegating-to-codex
description: Decide whether to hand a task to the OpenAI Codex CLI instead of doing it in this session, and how to run it if so. Covers the measured cost of delegation, the cases where it pays and the larger number where it does not, cross-review via `codex exec review`, sandbox selection, and how to receive results without undoing the context savings. Use when Claude's usage limit is close, when a second model's review is wanted, or when considering delegating investigation or implementation work to Codex.
---

# Codex への委譲

`codex exec` は Codex CLI を非対話で走らせる。別アカウント・別クォータのモデルに
仕事を渡せるが、**ほとんどの場合は渡さない方が速く安い**。この skill は主に
「渡さない」判断をするためにある。

## 前提

`codex` が PATH にあり `codex --login` 済みであること。未導入なら委譲しない。

```bash
codex --version    # 導入と疎通の確認
```

## まず: 委譲しない理由の方が多い

実測（3タスク × 3方式、akibako-agent リポジトリ、2026-08-30）:

| タスク | 自分で読む | Claude subagent | Codex 委譲 |
|---|---|---|---|
| 21ファイル 1,215行 | 12,480 | **45,588** | **204,149** |
| 4ファイル 40KB | 11,512 | **50,257** | **164,926** |
| **1ファイル 110行** | **1,038** | **35,751** | **99,076** |

単位は消費トークン。太字は委譲先の内部消費。

読み取れること:

- **1ファイル読むだけなら自分で読む。** subagent で34倍、Codex で95倍のトークンを払う。
- **親 context の節約なら subagent で足りる。** 21ファイルのタスクで、親に返ったのは
  subagent 約2,000 / Codex 約1,400。差は5ポイントで、委譲の手間に見合わない。
- **Codex は同じ仕事に 3.6倍のトークンを使った**（合計 468,151 対 131,596）。
  探索コマンドを何度も走らせるため。**総量は増える。**

> [!important] 委譲は「節約」ではなく「移転」
> Codex に渡してもトークン総量は減らない。減るのは *Claude 側の* 消費だけ。
> これが価値になるのは、Claude の枠が実際に逼迫しているときに限られる。

## 委譲してよい条件

以下の**いずれか**を満たすときだけ。満たさないなら自分でやるか subagent を使う。

1. **Claude の利用上限が近い、または到達した** — 作業を止めないための退避
2. **別モデルの視点でレビューさせたい** — 同じモデルの self-review では見えない指摘を得る
3. **長時間かかり、その間に別の作業を進めたい** — 数分かかる調査を投げて並行する

満たさない典型例:

- 1〜2ファイルの確認 → 自分で読む
- context を節約したいだけ → **subagent を使う**（実測で同等、かつ速い）
- 「念のため」「一応」 → 委譲しない

## 使い方

### cross-review（最も価値が高い用途）

専用サブコマンドがある。プロンプトを書く必要はない。

```bash
codex exec review --uncommitted          # 未コミットの変更（staged/unstaged/untracked）
codex exec review --base main            # main との差分
codex exec review --commit <SHA>         # 特定コミット
```

自分のレビューを終えた**後**に走らせ、**指摘が重なるか分かれるか**を見る。
重なれば確度が上がり、分かれた指摘は個別に判断する。Codex の指摘を無条件に
採用しない。

### read-only の調査

```bash
codex exec --sandbox read-only --cd <repo> "<task>"
```

`--sandbox read-only` を**必ず付ける**。実測で `files_modified` が0件になることを
確認済み。付け忘れると既定のサンドボックス設定が使われる。

タスク文の書き方:

- 何を読むか、何を報告するかを具体的に書く
- **「見つからなければ、無いと明言せよ」を入れる** — 入れないと、無いものを
  でっち上げる余地が残る
- 出典（ファイルパス・行番号）を要求する

### 構造化出力が欲しいとき

```bash
codex exec --output-schema schema.json --sandbox read-only "<task>"
```

最終応答を JSON Schema に従わせる。要約を機械処理したいときだけ使う。

### 続きから再開する

```bash
codex exec resume --last "<follow-up>"      # 直近のセッション
codex exec resume <SESSION_ID> "<follow-up>"
```

## 結果の受け取り方

> [!warning] 全文を読むと委譲の意味が消える
> `codex exec` の出力全体を context に流し込むと、節約したはずの分を
> その場で使い切る。

- **既定は最終応答だけを読む。** 途中の探索ログは読まない。
- 長い出力はファイルへリダイレクトし、**必要な箇所だけ**を読む。
- Codex が「テストが通った」と書いていても、**自分で確認するまで通ったことにしない**
  （`AGENTS.md` §3 / §4）。委譲先の自己申告は「著者の主張」であって検証済みの事実ではない。

```bash
codex exec --sandbox read-only "<task>" > /tmp/codex-out.md
# 必要な部分だけ読む
```

## 書き込みを伴う委譲

MVP では**やらない**。read-only だけに留める。

理由: 書き込みを許すと、同じ作業ツリーを自分と Codex が同時に触る危険、中途半端な
変更の残留、ロールバック手段、diff の検証手順がすべて必要になる。read-only には
どれも要らない。

どうしても必要なら、**専用の git worktree を切ってそこだけを書き込み可能にする**。
`main` を Codex に触らせない。マージは人間が行う（`AGENTS.md` §8）。

## 既知の落とし穴

- **固定オーバーヘッドがある。** 自明なプロンプトでも input 約22,000トークン
  （Codex 側の skill/plugin 定義が毎回載るため）。軽いタスクほど割に合わない。
  `~/.codex/skills/` の未使用 skill を無効化すると下がる。
- **初回は遅い。** 実測で初回 10.9秒、以降 4〜7秒。連続で投げる方が効率が良い。
- **`error` item は失敗とは限らない。** "Skill descriptions were shortened" のような
  警告も `error` として出る。終了状態で判定すること。
- **`~/.codex/config.toml` の `notify` を上書きしない。** 一部の委譲ツールは
  ジョブごとに `-c notify=` を注入するが、既存の連携を壊す。

## 関連

- 委譲するか自分でやるかの前段の判断 → `skills/session-bootstrap/SKILL.md`
- 受け取った指摘をどう扱うか → `skills/reviewing-changes/SKILL.md`
- 事実と解釈を混ぜない原則 → `AGENTS.md` §3
