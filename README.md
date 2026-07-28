# AI_dev_template

AIコーディングエージェント（Claude Code、Codexなど）と人間が安全に協働するための、軽量な開発テンプレート生成ツール。

## AI支援開発で解決する問題

AIコーディングエージェントに開発を任せていると、こういうことが起きる。

- **エージェントが文脈を見失う** — セッションが変わると、何を目指していたか・何を決めたかが消える
- **仕様が暗黙に変わる** — 「ついでに」直した箇所が、実は合意していない仕様変更だったりする
- **スコープ外の変更が紛れ込む** — 頼んでいないリファクタリングや大量のファイル生成が増える
- **中断後に再開しづらい** — どこまでやったか、どこで止まっていたかがチャット履歴の中に埋もれる
- **検証結果や意思決定が残らない** — 「テストは通しました」は本当か？ なぜその設計にしたのか？ が後から分からない

このテンプレートは、これらをチャットの記憶ではなく **Git管理されたファイル** へ外部化することで対応する。プロジェクトの状態（`memory/current-state.md`）、意思決定の記録（`memory/decisions.md`）、作業境界（Goal / Scope / Out of Scope / Stop Conditions）、検証結果（`verify.sh`の実行結果と `record-verification.sh` の記録）が、すべてファイルとして残り、次のセッション・別のエージェント・人間のレビュアーが読める形になる。

## 30秒で試すQuick Start

```bash
git clone https://github.com/Monet828/AI_dev_template.git
cd AI_dev_template
./scripts/setup/new-project.sh /path/to/new-project full
cd /path/to/new-project
./scripts/setup/doctor.sh
```

`doctor.sh` が `passed: N, warnings: 0, errors: 0` を表示すれば、プロジェクトは正しく生成されている。

## 生成されるもの

`new-project.sh`（内部で `scaffold.sh` を呼ぶ）は、`template/` にあるベーステンプレートと、選択した `packs/` をマージして、指定したディレクトリに新しいプロジェクトを作る。生成先には以下が含まれる。

- `AGENTS.md` / `CLAUDE.md` — AIエージェント共通の作業ルール
- `app/` — デプロイ対象のアプリ本体
- `docs/` — 正式仕様、ADR、運用知識
- `memory/` — 作業記憶（current-state / decisions / tasks / sessions）
- `scripts/` — bootstrap、doctor、verify、hooks、loop補助
- `skills/` / `assets/` — 再利用可能な能力・資産
- `.ai-dev-template.yml` — どの `template_version` / `profile` / packで生成されたかの記録
- `LICENSE`（MIT、プレースホルダーのコピーライト表記入り）

生成先には**含まれない**もの: このリポジトリ自身の生成ツール（`scaffold.sh`/`new-project.sh`）、`packs/`（pack管理コードは生成後は使えないため）、このリポジトリ自身のテスト（`tests/regression/`）、このリポジトリ自身のREADME/CI、`.git`。詳しい仕分けの理由は [`CONTRIBUTING.md`](CONTRIBUTING.md) を参照。

## profile一覧

`new-project.sh <target_dir> <profile>` で使えるprofile。

| profile | 適用されるpack |
|---|---|
| `minimal` | なし |
| `understand` | `understand-first` |
| `research` | `understand-first`, `evidence-first` |
| `strategy` | `evidence-first`, `problem-first` |
| `full` | `understand-first`, `evidence-first`, `problem-first` |
| `full-slides` | `understand-first`, `evidence-first`, `problem-first`, `slides` |

profileの代わりに `--packs pack1,pack2` でpackを直接指定することもできる（この場合profileのマッピングは使われない）。

## pack一覧

| pack | 何を解決するか | 主な追加物 |
|---|---|---|
| `understand-first` | 既存コードや既存仕様を理解してから触る | `memory/understanding-map.md`, `scripts/workflows/understand-first.sh` |
| `evidence-first` | 提案や比較の前に根拠を先に積む | `memory/evidence-log.md`, `scripts/workflows/evidence-first.sh` |
| `problem-first` | 何を解くかを先に定義し、分解して進める | `memory/problem-map.md`, `docs/templates/PROBLEM-BRIEF.md`, `scripts/workflows/problem-framing.sh` |
| `slides` | スライド資産を追加する | `assets/slides/SLIDE-md/`, `assets/slides/SLIDE-PATTERN/` |

各packの `pack-manifest.sh` に実際のバージョンがあり、生成時に `.ai-dev-template.yml` へ記録される。

## 安全性とGit運用

- `scripts/hooks/pre-push` は**opt-inのpre-pushフック**で、保護ブランチ（main/master/develop/integration/release、および`origin`のdefaultブランチ）への直push・force pushを検出してブロックする。導入するには `./scripts/hooks/install-hooks.sh` を明示的に実行する必要があり、**デフォルトでは何もインストールされない**。
- このフックは**セキュリティ境界ではない**。`ALLOW_PROTECTED_PUSH=1 git push ...` で人間が意識的に上書きできるし、`--no-verify` でも回避できるし、`install-hooks.sh` を実行していなければ最初から動作しない。AIエージェント自身が環境変数を設定して回避することもできてしまう。`scripts/hooks/{pre-task,post-task,stop,save-memory}.sh` はこれとは別物で、そもそもgit hookではなくAIエージェント向けの手動チェックポイント台本である。
- 本当の保護境界はGitHubの branch protection / ruleset である。例（`gh` CLI、コピペして自分で実行するためのものであり、このリポジトリのスクリプトが自動実行することはない）:
  ```bash
  gh api repos/:owner/:repo/rulesets -X POST \
    -f name='protect-main' \
    -f target='branch' \
    -f enforcement='active' \
    -f 'conditions[ref_name][include][]=refs/heads/main' \
    -f 'rules[][type]=pull_request'
  ```
- 生成処理自体はトランザクショナル: `scaffold.sh` は一時ディレクトリで組み立て、全工程が成功して初めて指定先へ移動する。既存の（空でない）ディレクトリを上書きすることはない。

## 検証方法

生成先プロジェクトの中で:

```bash
./scripts/loop/verify.sh
```

`pyproject.toml`/`package.json`/`Cargo.toml`/`go.mod` の有無と設定内容を検出し、実際に構成されているテスト/lint/buildだけを実行する。shell構文チェックは常に実行する。出力は `[PASS]`/`[SKIP: 理由]`/`[FAIL]` で、設定されているのに失敗した項目が1つでもあれば非0で終了する。

結果と所感を `memory/sessions/` に残したい場合は、続けて:

```bash
./scripts/loop/record-verification.sh
```

このリポジトリ自身（AI_dev_template側）の検証は:

```bash
find . -type f -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -n 1 bash -n
shellcheck $(find . -type f -name '*.sh' -not -path './.git/*')
./tests/regression/run.sh
```

## Example

`examples/` に、実際の生成コマンドで再現できる小さな例が1つある。課題設定、選んだprofile/pack、生成された主要ファイル、session logの例、decision recordの例、`verify.sh` の実行結果、中断後に別エージェントが再開する例をまとめてある。詳しくは [`examples/README.md`](examples/README.md)。

## 設計思想

- プロジェクトの状態・仕様・判断・スコープ境界・検証記録は、チャットの記憶ではなくバージョン管理可能なファイルへ外部化する
- 本体テンプレートはpackなしで自己完結している
- 特化した開発スタイルは `packs/` 配下のopt-inパックとして追加する
- `docs/` は正式仕様、`memory/` は作業記憶として分離する
- 生成は破壊的でない・トランザクショナルである

## 非目標

- 大規模なGUI
- Webサービス化
- npm/pipなどへの公開
- 複雑なplugin marketplace
- AIモデルAPIの直接統合
- 全スクリプトの別言語への全面書き換え

## 制約

- シェルスクリプトはmacOS標準の `/bin/bash`（3.2系、bash 4+専用構文は使用不可）とLinuxの両方で動作することを前提にしている。CIは `ubuntu-latest`/`macos-latest` の両方で検証する。
- `verify.sh` のエコシステム検出はヒューリスティック（`package.json` のプレースホルダースクリプトの判定など）であり、完璧ではない
- pack manifestは現状 `source` される平文シェルである（詳細は [`SECURITY.md`](SECURITY.md)）

## コントリビューション

[`CONTRIBUTING.md`](CONTRIBUTING.md) を参照。特に「`template/` と リポジトリルートの違い」は最初に読むこと。

## ライセンス

[MIT License](LICENSE)。生成先プロジェクトにも、コピーライト表記がプレースホルダーになった同ライセンスが含まれる（`template/LICENSE`）。
