# Project Structure

このドキュメントは、`AI_dev_template` における推奨ディレクトリ構成を定義する。

## 目的

- 正式仕様と再利用資産を分離する
- 実装本体とテストを明確に分ける
- Claude / Codex どちらでも迷いにくい入口を作る

## 主要ディレクトリ

### `src/`

アプリケーション本体を置く。

主な対象:

- UI
- API
- domain logic
- data access
- type definitions

### `tests/`

`src/` を検証するコードを置く。

主な対象:

- unit tests
- integration tests
- e2e tests
- fixtures

推奨:

- 可能な限り `src/` と対応が分かる構成にする
- テストだけが仕様の正本にならないようにする

### `docs/`

確定した仕様、方針、ADR、運用知識を置く。

主な対象:

- architecture
- setup
- API contracts
- ADR
- operational rules

### `assets/`

仕様そのものではない再利用資産を置く。

主な対象:

- design assets
- reusable reference artifacts
- opt-in pack が導入する補助資産

### `memory/`

AIエージェントと開発者の共有作業記憶を置く。

### `scripts/`

bootstrap、doctor、hooks、loop 補助を置く。

## 判断基準

- 長期的に参照される仕様や設計判断は `docs/`
- 実行可能な本体は `src/`
- 本体の検証は `tests/`
- 再利用資産は `assets/`
- セッション記録や短期記憶は `memory/`

## Pack 方針

- 本体テンプレートは pack なしで自己完結していること
- 問題分解、スライド資産のような特化機能は `packs/` 配下の opt-in pack として追加すること
