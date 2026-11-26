---
description: 自分の PR を、マージしてよい状態かを確かめてからマージし、スタックの上段の付け替え・手元の worktree とブランチの片付け・課題と関わるセッションへの知らせまで行う。PR を指定しなければ、マージできる状態の自分の PR を一覧にして選ばせる。ユーザーが /merge-prs を打ったときだけ動く（AI からは呼べない）。
argument-hint: "[PR 番号 または URL｜--pr <PR 番号 または URL>]（繰り返し可）（省略時はマージできる候補を一覧にして選ぶ）"
disable-model-invocation: true
---

引数は名前付き（ `--pr <PR 番号 または URL>`。繰り返して複数を渡せる）でも渡せる。位置で渡したときと同じに扱い、名前付きは順不同で渡してよい。

自分の PR をマージし、マージした後の片付けまでを1回で済ませます。

**このスキルを呼ぶこと自体が、マージの明示指示です**（ `decide_or_ask.md` の「取り消せない操作は、指示が一意に読めるときだけ」）。ただし指示が及ぶのは、手順2の条件をすべて満たした PR だけです。満たさない PR はマージせず、理由を報告します。

## 進め方

### 1. 対象の特定

- 自分のアカウント名を引く（ `gh api user -q .login` ）
- **引数があれば、その PR だけを対象にする**
- **引数が無ければ、候補を一覧にして選ばせる。** 自分の open な PR を全リポジトリから引き、手順2の条件で絞った一覧を `AskUserQuestion` の `multiSelect` で出す。条件を満たさない PR は、満たさない理由と一緒に本文に並べ、選択肢には入れない

  ```bash
  gh search prs --owner <OWNER> --author <自分> --state open --limit 100 --json repository,number,title,isDraft
  ```

- **作成者が自分でない PR は飛ばして報告する**（ `no_operating_on_others_prs.md` ）
- **閉じた PR は飛ばす。** マージ済み・クローズ済みは操作しない

### 2. マージしてよい状態か

**次の条件を1つでも満たさない PR はマージしない。** 止めた PR と理由を報告し、ほかの PR は進める。

| 条件 | 確かめ方 |
| --- | --- |
| ready で、approve を受けている | `gh pr view <PR> -R OWNER/REPO --json isDraft,reviewDecision` が `false` と `APPROVED` |
| 衝突が無い | `mergeable` が `MERGEABLE`（ `UNKNOWN` なら少し待って取り直す） |
| 必須のチェックがすべて成功している | `gh pr checks <PR> -R OWNER/REPO --required` に `fail` と `pending` が無い |
| 人間のレビューのスレッドが残っていない | 下の GraphQL で、`isResolved` が `false` のスレッドに、自分の返信が付いているか。返信の無いスレッドが1つでもあれば止める |
| マージの順番を守っている | PR 本文と、紐づく課題に書いた「先に入れる PR」が、すでにマージされている |
| PR 本文が差分と食い違っていない | `/update-pr-description` の手順5（本文と差分の照合）を通す。食い違えば直してから進める |

```bash
gh api graphql -f query='query{repository(owner:"OWNER",name:"REPO"){pullRequest(number:<PR>){reviewThreads(first:100){nodes{isResolved comments(first:50){nodes{author{login} authorAssociation}}}}}}}'
```

**返信の無い人間のスレッドを残したままマージしない。** マージすると PR が閉じ、指摘したレビュアーには対応が届かないまま終わります（ `responding_to_reviews.md` ）。返信の案は `/resolve-human-reviews` が作るので、止めた理由と一緒にそれを案内する。

**approve を受けていても、会話が終わっているとは限らない。** approve の後に付いたコメントもスレッドで見る。

### 3. マージする

**マージの方法は、リポジトリの設定と直近のマージに合わせる。**

```bash
gh repo view OWNER/REPO --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed
```

| 許されている方法 | 使う方法 |
| --- | --- |
| 1つだけ | それ |
| 2つ以上 | 直近のマージ済み PR 5本で最も多い方法。並んだら `AskUserQuestion` で尋ねる |

```bash
gh pr merge <PR> -R OWNER/REPO --squash   # --merge / --rebase
```

- **ブランチは `gh pr merge` で消さない**（ `--delete-branch` を付けない）。スタックの上段が base にしているブランチを先に消すと、上段の PR が閉じる。消すのは手順4で上段を付け替えた後
- **マージキューのあるリポジトリでは、キューに入っただけで終わらない。** 手順4へ進む前に、`state` が `MERGED` になるのを待つ（ `/wait-for-ci` と同じく、バックグラウンドで待つ）
- **成功表示を根拠にしない。** `gh pr view <PR> -R OWNER/REPO --json state,mergedAt,mergeCommit` で取り直して、`MERGED` を確かめる
- **複数の PR は、手順2で確かめた順番どおりに1本ずつ出す。** 1本ずつ止まりうる操作なので、1つの Bash の呼び出しにまとめない（ `decide_or_ask.md` ）

### 4. スタックの上段を直す

マージした PR のブランチを base にしている PR が残っていれば、`/rebase-stack` に渡して付け替える。

```bash
gh pr list -R OWNER/REPO --base <マージした PR の head> --state open --json number,headRefName
```

- squash でマージしたなら、上段の差分に下段の変更が残って見える。付け替えた後に `gh pr diff` で、上段の差分が上段の変更だけになったかを確かめる
- 上段に人間のレビューが付いていたら、履歴を書き換えずに `git merge` で取り込む（ `no_rebase_under_human_review.md` ）
- 上段がほかのセッションの持ち物なら、付け替えずに、そのセッションへ伝える（手順6）

付け替えが済んだら、マージした PR のブランチをリモートから消す（ `git push origin --delete <head>` ）。リポジトリがマージ時に自動で消す設定なら、消えたことだけ確かめる。

### 5. 手元の worktree とブランチを片付ける

その PR のために作った手元の worktree と、ローカルのブランチを消す。

```bash
git worktree list
git worktree remove <path>
git branch -D <head>
```

- **未コミットの変更か、push していないコミットがあれば消さない。** 中身を報告して止める
- **ほかのセッションが使っていそうな worktree は消さない**（ `notify_related_repo_sessions.md` の「ほかのセッションの worktree は、まだ使っていそうなら消さない」）
- 作業ツリーの HEAD がそのブランチにあるなら、worktree ではないので、ブランチを切り替える前に作業ツリーを共有しているセッションへ伝える

### 6. 課題と関わるセッションへ知らせる

**課題**: PR 本文の課題の節が指す課題へ知らせる。

- **その課題に紐づく PR がすべてマージされたときだけ、ステータスを進める。** 1本でも残っていれば、ステータスは触らない
- 進める先のステータスの名前は、リポジトリやプロダクトごとに違う。非公開のルールに定めがあればそれに従い、無ければ進めずに報告する
- 起票者がユーザーでない課題は、ステータスを進める前に `AskUserQuestion` で尋ねる（ `verify_before_asserting.md` の課題票の扱いと同じ向き）

**セッション**: マージで待ちが解けた・前提が変わったセッションへ1行で伝える（ `notify_related_repo_sessions.md` ）。

| 伝える場面 | 例 |
| --- | --- |
| 相手の PR がこの PR のマージを待っていた | マージ順の制約が解けた |
| 相手の PR がこの PR の上に積んである | 付け替えた / 付け替えを頼む |
| 契約・設定がこの PR で変わった | いつから main に入ったか |

### 7. 完了報告

PR ごとに1行で返す。PR は `pull` の URL のリンクで書く（ `report_formatting.md` ）。

```
[repo#123](https://github.com/OWNER/REPO/pull/123) マージ済み（squash、abc1234）/ 上段: repo#124 を付け替え / worktree: 消した / 課題: ステータスを進めた
```

- 止めた PR は、満たさなかった条件と、次に何をすればよいか（ `/resolve-human-reviews` を呼ぶ、CI を待つ、など）を書く
- 片付けを飛ばしたもの（未コミットの変更が残っていた worktree など）は、理由を書く

## やってはいけないこと

- **手順2の条件を満たさない PR をマージすること**。とくに、返信の無い人間のスレッドを残したまま閉じること
- **`gh pr merge` の成功表示で、マージされたと判断すること**。取り直して `MERGED` を見る
- 上段の付け替えより先に、base のブランチを消すこと。上段の PR が閉じる
- 未コミットの変更や push していないコミットがある worktree を消すこと
- 紐づく PR が残っているのに、課題のステータスを進めること
- 他人の PR をマージすること（ `no_operating_on_others_prs.md` ）
- 複数のマージを1つの Bash の呼び出しにまとめること

## 関連

- `decide_or_ask.md` （取り消せない操作は指示が一意なときだけ）: このスキルの起動がマージの指示にあたる根拠
- `responding_to_reviews.md` （人間のレビューへの対応）: 返信せずにマージしない根拠。返信の案は `/resolve-human-reviews` が作る
- `/rebase-stack` （スタックへの伝播）: 手順4の付け替えの手順を持つ
- `/update-pr-description` （PR 本文の更新）: 手順2の本文と差分の照合を持つ
- `/ready-pr` （ready 化と reviewer の指定）: マージの前段。本スキルはその後
- `split_and_stack_prs.md` （下段を書き換えたら上段を作り直す）: squash で下段をマージすると上段が壊れる理由
- `notify_related_repo_sessions.md` （担当セッションへの連絡）: 手順5の worktree の扱いと、手順6の伝え方
