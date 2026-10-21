# 公開側を編集したあとの走査と連絡

`/organize-rules` の「どちら側を触ったかで分かれる」から開く。`home/` 側を編集したときだけ要る手順です。

**`home/` 側を編集したら、渡す前に固有名を走査する。** `pre-commit` は**ステージ後にしか走らない**ので、コミット担当へ渡す時点では未検査です。

```bash
python3 - <<'EOF'
import re, pathlib, os

# ~/.claude/AGENTS.md はリンクなので、実体から親を遡れば dotfiles の外からでも見つかる。
# settings.json を起点にしない。clauth が切り替えのたびに実ファイルへ置き換える
root = pathlib.Path(os.path.realpath(os.path.expanduser("~/.claude/AGENTS.md")))
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

**あわせて、表記の検査も掛けてから渡す。** 会話への応答と GitHub への投稿ではフックが自動で走りますが、ルールやスキルのファイルを書いたときには走りません。`/yomiyasu:yomiyasu` は言い回しを見る検査なので、この表記は見ません。

```bash
python3 ~/.claude/hooks/check-japanese-spacing.py <編集したファイル>
```

実際に、ほかのセッションから受けたルールの変更が、1日に4回この検査に当たりました。どれもインラインコードと全角の約物の境目で、受けた側が直してからコミットしています。

**最も混じるのは例です**（ `no_internal_names_in_public_assets.md` ）。指摘を受けた本文をそのまま例にすると差分が主張を示すので実例が早いのですが、**固有名も一緒に乗ります**。実例を使うこと自体は正しく、**そのあと落とす段が抜ける**。

**それから、dotfiles のセッションが起動していないか `ListAgents` で確認する。**

- 起動していれば `SendMessage` で**何をどう編集したか**を伝えてコミットを促す（ `notify_related_repo_sessions.md` ）。向こうは編集したことを知らない
- 起動していなければ**ユーザーへ1行**添える。「dotfiles に未コミットの変更が N 件」で足りる
- **自分で dotfiles をコミットしない**（ `decide_or_ask.md` ）。作業中のリポジトリと別の履歴を勝手に作らない

**編集のたびに毎回連絡しない。** 一連の作業が一段落した時点でまとめて1回。細切れに送ると、向こうがコミット単位を切れなくなります。

**通達へ返信しても、永続化は終わりません。** 別のセッションから知らせを受けて編集したとき、**返信先がコミット担当とは限りません**。返信で完結した気になりやすいので、**返信先に関わらず dotfiles のセッションへ送る**。
