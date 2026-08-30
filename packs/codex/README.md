# codex pack

`skills/delegating-to-codex/SKILL.md` の**機械層**。

skill 側は「いつ渡すか・何を渡すか・何を返させるか」を決める。その report 契約は
status / `files_modified` / コマンドの exit code を**機械的に**求めているが、
散文の規約は「お願い」でしかなく、毎回手で組み立てれば必ず崩れる。
このパックはその3つを実装で固定する。

`AGENTS.md` §9 の Git ガバナンスと同じ二層構造である
（**お願いの層** = skill、**強制の層** = ここ）。

## 入るもの

| パス | 役割 |
|---|---|
| `scripts/codex/delegate.sh` | read-only 委譲。機械的な report を返す |
| `scripts/codex/review.sh` | `codex exec review` のラッパ |
| `scripts/codex/report-schema.json` | `--output-schema` に渡す。`claims` の構造を強制する |

`AGENTS.md` には委譲アドオンの節が追記される。

## 前提

`codex` が PATH にあり `codex --login` 済みであること。`python3` も要る
（JSONL を機械的に読むため）。**どちらか欠けていれば委譲しない** —
degrade せずに exit 2 で止まる。

## 何を機械的に決めているか

| 項目 | 出どころ |
|---|---|
| `status` | `codex exec` の終了コード |
| `files_modified` | **git の前後比較**。Codex の自己申告は使わない |
| `commands` + exit code | JSONL の `command_execution` item |
| `usage` | JSONL の `turn.completed` |
| `summary` / `claims` / `risks` / `unresolved` | Codex（JSON Schema で構造を強制） |
| 詳細ログ | パスのみ返す。既定では読まない |

### `error` item を失敗の判定に使わない

Codex は助言的な通知にも `error` item を使う。実測で観測した例:

```
Skill descriptions were shortened to fit the 2% skills context budget.
```

これは正常な実行である。`error` の有無で status を決めると、**健全な実行を
失敗として報告する。** だから status は終了コードだけから決める。

### read-only 不変条件

`--sandbox read-only` は上書きできない。それに加えて、実行の前後で
`git rev-parse HEAD` と `git status --porcelain` を比較する。
変化していたら **exit 3 で止める**。サンドボックスが破られたときに、
黙って結果を返さないため。

## 落とし穴: stdin

`codex exec` は、プロンプトが引数で渡っていても**非対話の親プロセスでは stdin を
待って無限に止まる**ことがある。実測で 6分40秒待っても返らなかった
（エラーではなく、ハング）。

両スクリプトとも `</dev/null` を付けている。**生の `codex exec` を自動化するなら
同じことをすること。**

## 費用

固定オーバーヘッドが大きい。実測で `VERSION` 1ファイルを読ませただけで
**input 43,826 トークン**（うち cached 22,272）。

**軽いタスクほど割に合わない。** 1〜2ファイルの確認は自分で読む。
振り分けの実測表は skill の §1 にある。

## 使う

```bash
./scripts/codex/delegate.sh --label audit-auth "$(cat <<'TASK'
[目的]     認証まわりでトークン期限の検証が漏れている箇所を特定する
[対象]     src/auth/ 配下のみ。他は読まなくてよい
[報告形式] summary / claims / risks / unresolved
[反証条件] 見つからなければ、無いと明言せよ
[出典]     path:line で示せ
TASK
)"

./scripts/codex/review.sh --base main
```

`delegate.sh` は JSON を stdout に、人間向けの要約を stderr に出す。
続きは `--resume <THREAD_ID>` で投げる（新しいセッションを立て直すより安い）。
