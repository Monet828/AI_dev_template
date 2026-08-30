# AGENTS.md

Claude Code、Codex、その他AIエージェントがこのリポジトリで作業する際の共通ルール。
AIは設計・実装・レビュー・記録を支援する開発メンバーとして扱うが、**最終判断は人間が行う**。

このファイルは毎ターン context に載る。**破ると事故る規約だけ**をここに置き、手順書は
`skills/` に置いて必要な時だけ読む。詳細な手順が要るときは、下表の skill を読むこと。

## 手順書の所在（必要時のみ読む）

| いつ | 読むもの |
|---|---|
| 作業を開始する / 再開する / 迷って止まった | `skills/session-bootstrap/SKILL.md` |
| `memory/` を更新する / 昇格を判断する | `skills/managing-memory/SKILL.md` |
| 設計判断を記録する | `skills/recording-decisions/SKILL.md` |
| コードをレビューする | `skills/reviewing-changes/SKILL.md` |
| 長時間・複数セッションの作業を回す | `skills/running-loops/SKILL.md` |

## 1. 正本の順序

- `docs/` = 正式仕様（正本）、`memory/` = 作業記憶。**矛盾したら `docs/` を優先**する。
  ただし現在の作業状況は `memory/current-state.md` を見る。
- ディレクトリの役割は `docs/project-structure.md` を唯一の正とする。
- Claude Code / Codex の**内部記憶を正本にしない**。正本は
  `AGENTS.md` / `memory/current-state.md` / `memory/decisions.md` / `docs/` / `src/`。
  ツール固有設定は `.claude/` `.codex/` に置くが、共通ルールは本ファイルが優先。

## 2. 実装の作法

- 実装前に、目的・影響範囲・変更対象ファイル・リスクを確認する。
- 既存設計に反する変更をするときは、実装前に理由と代替案を提示する。
- 既存の責務分離・コードスタイルを壊さない。不要な抽象化を足さない。
- 変更は小さく分ける。**ついでの大規模リファクタリングをしない**。
- 推測で実装しない。不明点は仮定として明示する。
- 影響範囲が想定より広がったら、作業を止めて方針を確認する。

## 3. 事実と解釈を混ぜない

調査・比較では、最初から主観的な評価やおすすめを混ぜない。

- まず一次情報・公式ドキュメント・観測事実・出典・日付を整理する。
- **事実と解釈を分けて書く**。不明点と要確認点を明示する。
- 解釈・採用判断・意味づけを求められた場合のみ、事実の後段として書く。
- 自分で確認していないことを、確認した事実として書かない
  （「著者の主張」と「自分で検証した事実」を区別する）。

## 4. 検証

変更後は、必要に応じて型チェック・Lint・Unit test・Integration test・Build・手動確認を行う。

- `./scripts/loop/verify.sh` が設定済みのテスト/lint/buildを検出して実行する。
  未設定項目は `[SKIP]` として明示され、**成功扱いにはならない**。
- テストを実行できなかった場合は、**その理由と代替の確認方法を明記**する。
- 完了とみなす前に、少なくとも一度は verifier 観点で見直す。

## 5. 標準コマンド

利用可能なら以下を標準とする（未実装なら追加時に本節を更新）。

`./install.sh` / `./run.sh` / `./scripts/setup/bootstrap.sh` / `./scripts/setup/doctor.sh` /
`./scripts/hooks/{pre-task,post-task,stop,save-memory}.sh` /
`./scripts/loop/verify.sh`（実チェック。`[PASS]/[SKIP]/[FAIL]`）/
`./scripts/loop/record-verification.sh`（自己申告ログ。verify.sh 実行後に記録）/
`./scripts/loop/resume.sh`

## 6. 禁止事項

- 明示されていない大規模リファクタリング
- 不要なファイルの大量生成
- 仕様の暗黙変更
- テストを無視した実装
- `docs/` と矛盾する変更
- セキュリティ上危険なショートカット
- 秘密情報のログ出力
- **一時的な推測を正式仕様として記録すること**

## 7. 停止すべき境界条件

合意された目的と範囲の中では自律的に進めてよい（詳細は
`skills/session-bootstrap/SKILL.md`）。ただし以下に達したら**止まって人間に確認する**。

- 目的が曖昧で、解釈により成果物が大きく変わるとき
- 合意済みの範囲を超える変更が必要になったとき
- 新しい仕様決定・アーキテクチャ判断が必要になったとき
- **破壊的変更・不可逆操作・大規模リファクタリング**が必要になったとき
- **本番影響・認証・課金・権限・秘密情報**に関わるとき
- 妥当な検証手段がなく、安全に完了とみなせないとき

## 8. Git 運用ガバナンス

> [!important] この節は prose だけでは守られない
> 文章の規約は「お願い」であり、モデルは無視しうる。だから二層で担保する。
> **お願いの層** = 本節。**ハードストップの層** = `scripts/hooks/pre-push` と
> Claude Code の `PreToolUse` フック。強制はフックが担う。

- 全ての変更は **Pull Request 経由**で人間のレビューに出す。人間の明示承認なしに
  保護ブランチへ反映しない。
- **保護ブランチへの直接 commit / push を禁止**する（default / integration / release）。
  default は `git symbolic-ref --quiet --short refs/remotes/origin/HEAD` で自動検出。
  作業は必ず topic ブランチで行う。
- **`--force` / `-f` の push を禁止**する。`reset --hard` / `clean -f` /
  ブランチ強制削除などの破壊的操作は、**人間の明示指示があるときのみ**実行する。
- **無言 push を禁止する**。push 前に「何を・どのブランチへ・なぜ」を人間に告げ、
  PR を開く。push だけして黙る／PR を作らずに push する、は違反。
- **完了時は「PR を開いて人間に引き渡して停止」**する。マージ・リリースタグ付け・
  本番デプロイは人間の担当であり、エージェントは行わない。
- 導入: `scripts/hooks/install-hooks.sh` / 詳細:
  `docs/playbooks/git-governance-pretooluse.md`
