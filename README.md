# AI_dev_template

AI エージェントと人間が共有で使う、軽量な開発テンプレートです。
`meeting-hub` のような `app/` 中心の Web アプリ構成をそのまま切り出せる骨格に寄せています。

本体は最小構成に保ち、特化機能は `packs/` 配下の opt-in pack として追加します。  
Claude Code と Codex の両方で使うことを前提にしています。

## 何が入っているか

- `app/`
  - デプロイ対象のアプリ本体。Next.js などのフロント / API パッケージをここに置く
- `AGENTS.md`
  - このテンプレートの共通ルール。最優先の正典
- `CLAUDE.md`
  - Claude Code 向けの薄いアダプタ
- `docs/`
  - 正式仕様、運用ルール、ADR
- `supabase/`
  - DB マイグレーションや seed を置く任意ディレクトリ
- `memory/`
  - current state、decisions、tasks、sessions
- `scripts/`
  - install、bootstrap、doctor、hooks、loop 補助
- `src/`
  - `app/` から切り出した共通ライブラリ置き場
- `tests/`
  - `app/` 外の共通ロジックや補助コードの検証
- `packs/`
  - opt-in の追加機能
- `assets/`
  - 再利用する非コード資産

ディレクトリ構成の詳細は `docs/project-structure.md` を参照してください。

## 基本思想

- 本体テンプレートは pack なしで自己完結している
- 特定の開発スタイルは `packs/` として追加する
- `docs/` は正式仕様、`memory/` は作業記憶として分離する
- AI の内部記憶を正本にせず、markdown ファイルに状態を残す

## クイックスタート

### 1. テンプレートを取得する

```bash
git clone https://github.com/Monet828/AI_dev_template.git
cd AI_dev_template
```

### 2. 新規プロジェクトを切る / 既存構成を始める

おすすめの入口:

```bash
./scripts/setup/new-project.sh /path/to/new-project full
```

profile を使わず最小構成で切る:

```bash
./scripts/setup/new-project.sh /path/to/new-project
```

profile ではなく pack を明示したい場合:

```bash
./scripts/setup/new-project.sh /path/to/new-project --packs understand-first,evidence-first,problem-first
```

低レベルの直接コマンド:

pack なしの最小構成:

```bash
./scripts/setup/scaffold.sh /path/to/new-project
```

pack あり:

```bash
./scripts/setup/scaffold.sh /path/to/new-project --with understand-first,evidence-first,problem-first
```

### 3. 新規プロジェクト側で初期確認する

```bash
cd /path/to/new-project
./scripts/setup/doctor.sh
./scripts/setup/bootstrap.sh
```

## 利用可能な pack

### `understand-first`

既存コードや既存仕様を理解してから触るための pack です。

向いている場面:

- 既存リポジトリに入る
- 影響範囲を把握してから変更したい
- 責務や依存関係の誤解を減らしたい

主な追加物:

- `memory/understanding-map.md`
- `scripts/workflows/understand-first.sh`

### `evidence-first`

提案や比較の前に、根拠を先に積むための pack です。

向いている場面:

- 調査
- 比較検討
- 設計判断前のリサーチ

主な追加物:

- `memory/evidence-log.md`
- `scripts/workflows/evidence-first.sh`

### `problem-first`

何を解くかを先に定義し、North Star から分解して進める pack です。

向いている場面:

- 問題設定が曖昧
- issue が流れやすい
- 大目標と日々の作業をつなげたい

主な追加物:

- `memory/problem-map.md`
- `docs/templates/PROBLEM-BRIEF.md`
- `scripts/workflows/problem-framing.sh`

### `slides`

スライド資産を追加する pack です。

向いている場面:

- 提案資料やプレゼンを作る
- ローカルの slide 資産を再利用したい

主な追加物:

- `assets/slides/SLIDE-md/`
- `assets/slides/SLIDE-PATTERN/`

## pack のおすすめ組み合わせ

既存コードベースを安全に触る:

```bash
./scripts/setup/new-project.sh /path/to/new-project understand
```

調査から問題設定までやる:

```bash
./scripts/setup/new-project.sh /path/to/new-project strategy
```

既存コードを理解しつつ、根拠を集めて問題設定する:

```bash
./scripts/setup/new-project.sh /path/to/new-project full
```

資料作成も含める:

```bash
./scripts/setup/new-project.sh /path/to/new-project full-slides
```

## 標準コマンド

- `./install.sh`
- `./run.sh`
- `./scripts/setup/new-project.sh`
- `./scripts/setup/scaffold.sh`
- `./scripts/setup/doctor.sh`
- `./scripts/setup/bootstrap.sh`
- `./scripts/hooks/pre-task.sh`
- `./scripts/hooks/post-task.sh`
- `./scripts/hooks/save-memory.sh`
- `./scripts/hooks/stop.sh`
- `./scripts/loop/verify.sh`
- `./scripts/loop/resume.sh`

## meeting-hub 型の使い方

このテンプレートは、次のような構成をデフォルトにする。

```text
project/
├── app/                  # Next.js / Vite / API サービス本体
├── docs/                 # 要件、ADR、運用文書
├── scripts/              # 補助スクリプト
├── supabase/             # migrations / seed / functions
├── memory/               # 作業記憶
├── assets/               # 非コード資産
└── packs/                # opt-in 機能
```

`src/` は `app/` 外に共通ライブラリを切りたいときだけ使う。

## どこを読めばいいか

- 共通ルールを知りたい:
  `AGENTS.md`
- ディレクトリ構成を知りたい:
  `docs/project-structure.md`
- 現在の memory 運用を知りたい:
  `memory/README.md`
- loop engineering の基本を知りたい:
  `docs/playbooks/loop-engineering.md`

## 運用上の推奨

- テンプレート本体は GitHub を正本にして育てる
- 新規案件ごとに `scaffold.sh` で切り出す
- ローカルの雑なコピペ運用ではなく、pack を明示して再現可能にする
- 長期的な判断は `docs/` に昇格し、一時的な文脈は `memory/` に留める
