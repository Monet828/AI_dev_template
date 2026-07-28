# このプロジェクトについて

このプロジェクトは [AI_dev_template](https://github.com/Monet828/AI_dev_template) から生成された。AIコーディングエージェント（Claude Code、Codexなど）と人間が、プロジェクトの状態・仕様・判断・検証記録をチャットの記憶ではなくGit管理されたファイルへ残しながら開発するための構成になっている。

## 何で生成されたか

どのprofile・pack・テンプレートバージョンで生成されたかは、直下の `.ai-dev-template.yml` に記録されている。手で編集せず、変更したい場合は [AI_dev_template](https://github.com/Monet828/AI_dev_template) 側で再生成すること。

## 最初にすること

```bash
./scripts/setup/bootstrap.sh
```

現在の状態、共通ルール（`AGENTS.md`）、ディレクトリ構成（`docs/project-structure.md`）を表示し、今日のセッションログを `memory/sessions/` に作成する。

```bash
./scripts/setup/doctor.sh
```

必須ファイルが揃っているかを確認する。`errors: 0` であれば正常。`--json` を付けるとCI等で使える機械可読な出力になる。

## 何がどこにあるか

- `AGENTS.md` / `CLAUDE.md` — AIエージェントが最初に読むべき共通ルール
- `docs/project-structure.md` — ディレクトリ構成の判断基準
- `memory/` — 作業記憶（`current-state.md`、`decisions.md`、`tasks.md`、`sessions/`）
- `app/` / `src/` / `tests/` — アプリ本体、共有ロジック、その検証コード
- `agents/` — researcher / reviewer / verifier の役割定義

## 検証方法

```bash
./scripts/loop/verify.sh
```

`pyproject.toml`/`package.json`/`Cargo.toml`/`go.mod` の有無と設定内容を検出し、実際に構成されているテスト/lint/buildだけを実行する（`[PASS]`/`[SKIP: 理由]`/`[FAIL]`）。設定されているのに失敗した項目があれば非0で終了する。

```bash
./scripts/loop/record-verification.sh
```

`verify.sh` の結果と、人間/エージェントの所感をあわせて `memory/sessions/` に記録する。

## 安全性とGit運用

このプロジェクトにgit hookは一切インストールされていない（`scripts/hooks/*.sh` はgit hookではなく、AIエージェント向けの手動チェックポイント台本）。git hookは導入しても `--no-verify` で回避できるため、セキュリティ境界にはならない。ブランチ保護が必要な場合は、GitHubのbranch protection / rulesetをリポジトリ設定側で行うこと。

## もっとpackを追加したい場合

このプロジェクト自身には pack管理の仕組み（`packs/`、`scaffold.sh`）は含まれていない。[AI_dev_template](https://github.com/Monet828/AI_dev_template) 側で `new-project.sh`/`scaffold.sh` を実行するか、必要なファイルを手動でマージすること。

## ライセンス

[LICENSE](LICENSE)（MIT、プレースホルダーのコピーライト表記）。自分の名前/組織名に書き換えるか、別のライセンスに差し替えること。
