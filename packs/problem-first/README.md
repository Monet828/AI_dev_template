# problem-first

この addon は、problem-first development のための補助資産であり、実行時レイアウトではなく、scaffold 時に本体テンプレへマージされる配布パックである。

## 何を解決するか

- いきなり実装に入って、何を解くべきかが曖昧なまま進む
- issue が明文化されず、議論や仮説が流れる
- 大きな目的と日々の作業がつながらなくなる

## 基本思想

1. まず、プロジェクトの目的とコンセプトを言語化する
2. 次に、解くべき最大問題を 1 つに絞る
3. その問題を小問題へ分解する
4. いま潰すべき小問題を 1 つ決める
5. 検証し、次の小問題へ進む

## パック構造

- `pack-manifest.sh`
  - pack の基本情報と merge 元ディレクトリを定義する
- `merge/`
  - 新規プロジェクトへそのまま配置されるファイル
- `append/`
  - 既存ファイル末尾へ追記される断片

## 導入

新規プロジェクトには直接コピーせず、base template の scaffold から適用する。

## 使い方

1. scaffold で pack を適用する
2. `docs/templates/PROBLEM-BRIEF.md` を埋める
3. `memory/problem-map.md` を更新する
4. `./scripts/workflows/problem-framing.sh` で checkpoint を残す
5. 実装前に「いま潰す小問題」を 1 つ決める
