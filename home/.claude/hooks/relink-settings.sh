#!/bin/bash
#
# ~/.claude/settings.json がリンクでなくなっていたら、中身をリポジトリへ戻して
# 張り直す SessionStart フック。
#
# clauth はアカウントを切り替えるたびに settings.json を書き換える。プロファイルの
# env と model の設定を混ぜ込む仕様で、一時ファイルを rename するのでリンクが実体に
# 置き換わる。止める設定は無い。
#
# 放っておくと、リポジトリ側を編集しても効かない。動いているのは実ファイルのほうで、
# フックを足しても発火しない状態になる。
#
# 実ファイルの中身を正とする。clauth が書いた分を捨てないため。差分が出れば
# report-dotfiles-state.sh が未コミットとして知らせる。
set -u

S="$HOME/.claude/settings.json"
[ -e "$S" ] || exit 0
[ -L "$S" ] && exit 0   # リンクのままなら何もしない

# 起点は CLAUDE.md。settings.json を起点にすると、まさに壊れているときに引けない。
# clauth はこちらを触らない
link=$(readlink "$HOME/.claude/CLAUDE.md" 2>/dev/null) || exit 0
[ -n "$link" ] || exit 0
repo=$(git -C "$(dirname "$link")" rev-parse --show-toplevel 2>/dev/null) || exit 0

T="$repo/home/.claude/settings.json"
[ -f "$T" ] || exit 0

if ! cmp -s "$S" "$T"; then
  # clauth は末尾の改行を落とすので補う。放っておくと切り替えのたびに
  # 1バイトの差分が出て、未コミットとして毎回知らされる
  { cat "$S"; [ -n "$(tail -c1 "$S")" ] && echo || true; } >| "$T" || exit 0
  msg="中身をリポジトリへ戻して張り直しました"
else
  msg="張り直しました（中身は同じ）"
fi

rm -f "$S" && ln -s "$T" "$S" || exit 0
printf '%s\n' "~/.claude/settings.json が実ファイルになっていたので、${msg}。clauth がアカウントを切り替えると起きます"
