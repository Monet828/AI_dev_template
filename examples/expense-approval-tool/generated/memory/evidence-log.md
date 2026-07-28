# Evidence Log

## Research Question

- 経費精算のスプレッドシート運用のどこに一番の不満があるか

## Scope

- 経理部門責任者1名、部門責任者3名（営業・製造・管理）への社内ヒアリングのみ。外部文献調査は対象外。

## Sources Consulted

- Source: 経理部門責任者ヒアリング
  - Type: 社内ヒアリング（議事メモ）
  - Date: 2026-07-25
  - URL or reference: (社内議事メモ、非公開)
  - Why it matters: 承認・差し戻しフローの実態を最も把握している当事者
- Source: 営業部長ヒアリング
  - Type: 社内ヒアリング（議事メモ）
  - Date: 2026-07-26
  - URL or reference: (社内議事メモ、非公開)
  - Why it matters: 差し戻し発生頻度が最も高い部門
- Source: 製造部長ヒアリング
  - Type: 社内ヒアリング（議事メモ）
  - Date: 2026-07-28
  - URL or reference: (社内議事メモ、非公開)
  - Why it matters: 部門間の運用差異を確認するため

## Facts

- Fact: 経費精算は部門ごとにExcelブックをメール添付で経理へ送付し、経理が手動で承認・差し戻しをメール返信で行っている
  - Source: 経理部門責任者ヒアリング
  - Date: 2026-07-25
- Fact: 直近3ヶ月の差し戻し件数は月平均12件。うち5件は、差し戻し理由が後から追跡できず同じ指摘を繰り返したケース
  - Source: 経理部門責任者ヒアリング
  - Date: 2026-07-25
- Fact: 営業部門では差し戻し理由をメール本文にしか残しておらず、担当者交代時に経緯が分からなくなる
  - Source: 営業部長ヒアリング
  - Date: 2026-07-26

## Quotes or Summaries

- 「差し戻した理由を毎回同じ人に説明し直しているのが一番のストレス」（経理部門責任者、2026-07-25）

## Unknowns / Open Questions

- 製造部門は差し戻し頻度が低いが、それが運用が優れているからか、そもそも精算件数が少ないだけなのかは未確認

## Decision Impact

- 「差し戻し理由の追跡可能性」が最有力の課題仮説であることの根拠になる。次の問題設定（North Star）はこれを軸に検討する。

## Resume From

- next_state: plan_selected
- required_context: 上記Facts、製造部門の追加ヒアリング結果待ち
- blocking_reason: 製造部門の実態が「運用が良い」のか「母数が少ないだけ」なのかの切り分けがつくまで、North Starを確定させたくない
