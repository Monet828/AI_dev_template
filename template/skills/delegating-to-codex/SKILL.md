---
name: delegating-to-codex
description: Delegate work to the OpenAI Codex CLI as a second execution backend with its own quota and its own model. Covers when delegation pays and the larger number of cases where it does not, the task contract to hand over, the report contract to require back, cross-review via `codex exec review`, parallel dispatch, and error recovery. Use when Claude's usage limit is the binding constraint, when a second model's review is wanted, or when a long investigation should run alongside other work.
---

# Codex への委譲

Codex は**別クォータ・別モデルの実行系**であって、Claude の代替ではない。
この skill は「いつ渡すか」「何を渡すか」「何を返させるか」を決める。

`codex` が PATH にあり `codex --login` 済みであること。無ければ委譲しない。

## 1. 委譲の判断

### 実測（3タスク × 3方式、2026-08-30）

| タスク | 自分で読む | Claude subagent | Codex |
|---|---|---|---|
| 21ファイル 1,215行 | 12,480 | **45,588** | **204,149** |
| 4ファイル 40KB | 11,512 | **50,257** | **164,926** |
| **1ファイル 110行** | **1,038** | **35,751** | **99,076** |

単位は消費トークン。太字は委譲先の内部消費。

> [!important] 委譲は「節約」ではなく「移転」
> Codex は同じ3タスクに **3.6倍**のトークンを使った（468,151 対 131,596）。
> 探索コマンドを何度も走らせるため。減るのは *Claude 側の*消費だけで、総量は増える。

### 振り分け

| 状況 | 送り先 |
|---|---|
| 1〜2ファイルの確認 | **自分で読む**（委譲は34〜95倍のトークンを払う） |
| context を節約したい | **Claude subagent**（親への返却は Codex とほぼ同じ。実測で差5ポイント） |
| **Claude の枠が逼迫・到達** | **Codex**（作業を止めないための退避） |
| **別モデルのレビューが欲しい** | **Codex**（§4） |
| **長時間かかり、並行して別作業をしたい** | **Codex**（§5） |
| 書き込みを伴う実装 | **委譲しない**（§6） |

**「念のため」「一応」では委譲しない。** 上の3つのどれかに当てはまるときだけ。

## 2. 渡す契約（task）

プロンプトに以下を書く。**書かないと Codex は埋めない。**

```text
[目的]     何を明らかにする / 何を作るか
[対象]     読んでよいパス。触ってはいけないもの
[報告形式] §3 の項目を明示的に列挙する
[反証条件] 「見つからなければ、無いと明言せよ」  ← 必須
[出典]     ファイルパスと行番号を要求する
```

`[反証条件]` を省くと**無いものをでっち上げる余地が残る**。実測でも、これを入れた
タスクでは「バグは見つからなかった」と正直に返ってきた。

### なぜ Codex に振ったかを残す

委譲を決めたら、その理由を一行で残す（`memory/sessions/` か作業ログ）。

```text
routing: codex / 理由: Claude 5h枠が80%超。read-only調査なので退避先として適切
```

後から「なぜこれは委譲したのか」を再構成できないと、振り分け規則を改善できない。

## 3. 返させる契約（report）

要約だけでは検証できず、全文を読むと節約が消える。**この中間を要求する。**

| 項目 | 誰が作るか |
|---|---|
| `status` | 終了状態から**機械的に**（`error` item の有無で判定しない。§7参照） |
| `files_modified` | **機械的に**。Codex の自己申告を使わない |
| `commands` + exit code | **機械的に**。テスト結果はここから読む |
| `summary` | Codex（3文以内） |
| `risks` / `unresolved` | Codex |
| `claims` | Codex（下記） |
| 詳細ログ | **パスのみ**。既定では読まない |

### claims — 反証は失敗ではない

判断を左右する主張を**最大3件**、状態つきで返させる。

```text
claim:    "重複書き込みが起きている"
status:   confirmed | falsified | uncertain
evidence: "330組すべて supersedes による正規動作。raw と logical の混同だった"
```

**`falsified` から修正タスクを作らない。** 誤った前提を潰したこと自体が成果であり、
そこで打ち切る。Codex が前提を反証して戻ってきたら、それは成功した委譲である。

> [!warning] 「テストが通った」を信じない
> Codex が通ったと書いていても、**自分で確認するまで通ったことにしない**
> （`AGENTS.md` §3 / §4）。委譲先の自己申告は「著者の主張」であって検証済みの
> 事実ではない。`commands` の exit code を見るか、自分で再実行する。

## 4. cross-review

専用サブコマンドがある。プロンプトを書く必要はない。

```bash
codex exec review --uncommitted     # 未コミットの変更
codex exec review --base main       # main との差分
codex exec review --commit <SHA>    # 特定コミット
```

**自分のレビューを終えた後に走らせる。** 先に走らせると自分の判断が引きずられる。

- **重なった指摘** → 確度が上がる。優先して対処
- **分かれた指摘** → 個別に判断。Codex が正しいとは限らない
- **Codex だけが挙げた指摘** → 自分が見落とした観点か、誤読か。根拠を確認してから採否

無条件に採用しない。§3 と同じで、これも「著者の主張」である。

## 5. 並列で投げる

独立した調査が複数あるときだけ。依存があるなら順に投げる。

```bash
codex exec --sandbox read-only --cd <repo> "調査A" > /tmp/a.md &
codex exec --sandbox read-only --cd <repo> "調査B" > /tmp/b.md &
wait
```

**投げたら統合するまでが一手。** 結果を並べて、矛盾があれば矛盾として記録する
（片方を黙って捨てない）。

### 続きから再開する

```bash
codex exec resume --last "<follow-up>"
codex exec resume <SESSION_ID> "<follow-up>"
```

新しいセッションを立て直すより安い。**同じプロンプトで再試行しない**（§8）。

## 6. 書き込みを伴う委譲

**やらない。read-only に留める。**

```bash
codex exec --sandbox read-only --cd <repo> "<task>"
```

`--sandbox read-only` を**必ず付ける**。実測で `files_modified` が0件になることを
確認済み。付け忘れると既定のサンドボックス設定が使われる。

書き込みを許すと、同じ作業ツリーを自分と Codex が同時に触る危険、中途半端な変更の
残留、ロールバック手段、diff の検証手順がすべて必要になる。read-only にはどれも要らない。

**どうしても必要になったら**: 専用の git worktree を切り、そこだけを書き込み可能に
する。`main` を Codex に触らせない。マージは人間が行う（`AGENTS.md` §9）。

## 7. 既知の落とし穴

- **固定オーバーヘッド 約22,000トークン。** 自明なプロンプトでもかかる（Codex 側の
  skill/plugin 定義が毎回載る）。軽いタスクほど割に合わない。`~/.codex/skills/` の
  未使用 skill を無効化すると下がる。
- **初回が遅い。** 実測で初回 10.9秒、以降 4〜7秒。連続で投げる方が効率が良い。
- **`error` item は失敗とは限らない。** "Skill descriptions were shortened" のような
  警告も `error` として出る。**`error` の有無で status を決めない。**
- **`~/.codex/config.toml` の `notify` を上書きしない。** ジョブごとに `-c notify=` を
  注入する third-party ツールがあるが、既存の連携を壊す。
- **`--output-schema <FILE>`** で最終応答を JSON Schema に従わせられる。要約を機械
  処理したいときだけ使う。

## 8. うまくいかないとき

| 症状 | 対処 |
|---|---|
| 見当違いの方向へ進んだ | **同じプロンプトで再試行しない。** 何が違ったかを足して投げ直す |
| 出力が長すぎる | ファイルへリダイレクトし、必要な箇所だけ読む |
| 途中で止まった | `codex exec resume --last` で続ける |
| 何度やっても失敗する | **タスクが大きすぎる。** 分割するか、自分でやる |
| 結果が信用できない | 委譲をやめる。検証コストが節約を上回っている |

**同じ失敗を3回繰り返したら、やり方が間違っている**（`skills/running-loops/SKILL.md`
の retry_budget と同じ判断）。

## 関連

- 委譲するか自分でやるかの前段 → `skills/session-bootstrap/SKILL.md`
- 受け取った指摘の扱い → `skills/reviewing-changes/SKILL.md`
- 事実と解釈を混ぜない原則 → `AGENTS.md` §3
