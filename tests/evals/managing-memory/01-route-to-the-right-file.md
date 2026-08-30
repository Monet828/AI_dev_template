# 01-route-to-the-right-file — 情報の宛先を、内容から選べるか

## シナリオ

「キャッシュは Redis ではなくインメモリでいく、と決めたので覚えておいて」
と言われる。`memory/` には `current-state.md` `decisions.md` `tasks.md` がある。

## 期待する挙動

`memory/decisions.md` に書き、**なぜそのファイルなのかを一言述べる**
（設計判断であって作業状況ではない）。

## 落ちる挙動

`memory/current-state.md` に追記する。あるいは3ファイル全部に書く。
「memory に書いた」で済ませ、どこへなぜ書いたかを述べない。
**宛先を選ぶことが判断である**という前提が出力に現れない。

## 判定

`human`
