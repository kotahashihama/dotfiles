# グローバル資産を編集したら、永続化まで見る

`~/.claude/` の資産を編集しただけでは履歴に残りません。**環境を作り直すと消えます。**
これは全プロジェクト共通の規約です。

**編集と永続化は別のセッションで起きます。** 触ったのは作業中のリポジトリのセッションですが、コミットするのは dotfiles のセッションです。**放っておくと誰もコミットしません。**

## どちら側を触ったかで分かれる

`~/.claude/` の実体は dotfiles リポジトリで、**シンボリックリンク越しに編集しています**。

| 実体の置き場 | git | 編集後 |
| --- | --- | --- |
| `home/.claude/` （rules / skills / hooks / agents / settings.json / CLAUDE.md） | **管理下** | **コミットが要る** |
| `private/.claude/` と `private/.claude-memory/` （メモリ・社内固有名を含むスキル） | `.gitignore` 対象 | 不要 |

**どちら側かの見分け方は `no_internal_names_in_public_assets.md` が持ちます**（スキルは両側にあり、リンク越しでは判別できない）。**`private/` 側なら連絡は要りません。**

**`home/` 配下は公開リポジトリなので、社内固有名を書けません。** 何を書いてよいかは `no_internal_names_in_public_assets.md` が規定します。

**`home/` 側を編集したら、渡す前に固有名を走査する。** `pre-commit` は**ステージ後にしか走らない**ので、コミット担当へ渡す時点では未検査です。

```bash
python3 - <<'EOF'
import re, pathlib, os

# ~/.claude/settings.json はリンクなので、実体から親を遡れば dotfiles の外からでも見つかる
root = pathlib.Path(os.path.realpath(os.path.expanduser("~/.claude/settings.json")))
deny = next(p / "private/.claude/deny-patterns.txt" for p in root.parents
            if (p / "private/.claude/deny-patterns.txt").exists())
pats = [l.strip() for l in deny.read_text(encoding="utf-8").splitlines()
        if l.strip() and not l.startswith("#")]

for f in ["<編集したファイル>"]:
    t = pathlib.Path(os.path.expanduser(f)).read_text(encoding="utf-8")
    for p in pats:
        for m in re.finditer(p, t, re.I):
            print(f"NG {f} : {m.group(0)}")
EOF
```

**相対パスで書かない。** この走査を掛けるのは**他リポジトリで作業しているセッション**なので、dotfiles の作業ツリーにいません。

**0件が返ったら、非公開側のファイルへ同じ走査を掛ける。** 当たらなければ探し方が壊れています（ `verify_the_check_worked.md` ）。

**最も混じるのは例です**（ `no_internal_names_in_public_assets.md` ）。指摘を受けた本文をそのまま例にすると差分が主張を示すので実例が早いのですが、**固有名も一緒に乗ります**。実例を使うこと自体は正しく、**そのあと落とす段が抜ける**。

**それから、dotfiles のセッションが起動していないか `ListAgents` で確認する。**

- 起動していれば `SendMessage` で**何をどう編集したか**を伝えてコミットを促す（ `notify_related_repo_sessions.md` ）。向こうは編集したことを知らない
- 起動していなければ**ユーザーへ1行**添える。「dotfiles に未コミットの変更が N 件」で足りる
- **自分で dotfiles をコミットしない**（ `no_auto_commit.md` ）。作業中のリポジトリと別の履歴を勝手に作らない

**編集のたびに毎回連絡しない。** 一連の作業が一段落した時点でまとめて1回。細切れに送ると、向こうがコミット単位を切れなくなります。

**通達へ返信しても、永続化は終わりません。** 別のセッションから知らせを受けて編集したとき、**返信先がコミット担当とは限りません**。返信で完結した気になりやすいので、**返信先に関わらず dotfiles のセッションへ送る**。

## 禁止する挙動

- **走査せずに渡すこと**。`pre-commit` はステージ後にしか走らないので、渡した時点では誰も見ていない
- **編集して連絡しないこと**。環境を作り直した時点で消える
- **自分で dotfiles をコミットすること**。作業中のリポジトリと別の履歴を勝手に作らない（ `no_auto_commit.md` ）
- **編集のたびに連絡すること**。細切れに送ると、向こうがコミット単位を切れない
- **通達への返信で終えること**。返信先がコミット担当とは限らない

## なぜ

- **編集した側は、コミットされたかを見ていない。** 作業が続くので、そのまま忘れる
- **コミットする側は、編集されたことを知らない。** リンク越しなので、作業ツリーが汚れていることに気づくのは次に `git status` を打ったとき
- 消えたことに気づくのは**環境を作り直した後**で、そのときには何を書いたか思い出せない

## 例外

- `private/` 側の編集（ `.gitignore` 対象なのでコミット不要）
- ユーザーが「連絡不要」と明示した場合

## 関連

- `ask_before_editing_claude_assets.md` （設定は尋ねてから）: **本ルールは触った後**。あちらは触ってよいかの判断
- `no_internal_names_in_public_assets.md` （公開側に社内固有名を書かない）: **どちら側かの見分け方**をあちらが持つ
- `notify_related_repo_sessions.md` （担当セッションへ連絡する）: 連絡の形はあちらが定める
- `no_auto_commit.md` （コミットは明示指示のみ）: 自分でコミットしない根拠
