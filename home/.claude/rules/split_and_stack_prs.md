# 下段の履歴を書き換えたら、上段を作り直す

スタックした PR で下段の履歴が入れ替わると（force push・rebase・squash マージ）、上段の差分が壊れます。警告は出ず、気づけるのは差分の行数が跳ねたときだけです。下段を書き換えたら上段を作り直してください。上段に他の人のレビューが付いているなら、作り直さず `git merge` で取り込みます（ `no_rebase_under_human_review.md` ）。
これは全プロジェクト共通の規約です。

**PR を積む・下段を書き換える・`gh stack` を使うときは、`~/.claude/references/split_and_stack_prs.md` を読む。** 壊れ方の実測、`gh stack link` に既存のスタックの一部だけを渡したときの事故、禁止する挙動はそちらにある。作り直しの手順は `/rebase-stack` が持つ。

## 関連

- `report_formatting.md` （報告に貼る識別子の書式）: スタックを報告するときも PR 番号を直接列挙する
- `no_rebase_under_human_review.md` （レビュー中は履歴を書き換えない）: スタックの取り込み方を上段のレビュー状況で切り替える。一度でも merge したブランチは rebase しない。マージコミットが平坦化され、衝突の解決ごと消える
- `verify_merge_with_checks.md` （マージは検査を通すまで終わっていない）: 本ルールは取り込む前の依存判定、あちらは取り込んだ後の検証
- `/update-pr-description` （PR 本文の組み立て）: 分けた後、説明の書き方を揃えるのはあちら。本ルールは分ける判断とマージ順を扱う
- `/rebase-stack` （スタックへ伝播する）: 実行手段
- `scope_changes_to_the_issue.md` （課題の範囲へ変更を閉じる）: 分ける前に、その変更を入れるかどうかはあちらが決める
- pstack の `principle-sequence-verifiable-units` （確かめられる単位に切って積む）: 分け方と積み方の考え方。本ルールは下段の履歴が変わったときの作り直し
