#!/bin/bash
#
# グローバル資産に未コミットの変更が残っていることを、セッション開始時に伝える
# SessionStart フック。
#
# `~/.claude/` の実体は dotfiles リポジトリで、編集しただけでは履歴に残らない。
# 編集したセッションが伝え漏らすと、次に気づく機会が無い
# （ask_before_editing_claude_assets.md の「編集したら永続化まで見る」）。
#
# 変更が無ければ何も言わない。
#
set -u

# settings.json のリンク先から dotfiles の作業ツリーを引く。
# パスを直接書くと、リポジトリを移したときに黙って効かなくなる。
link=$(readlink "$HOME/.claude/settings.json" 2>/dev/null) || exit 0
[ -n "$link" ] || exit 0
repo=$(git -C "$(dirname "$link")" rev-parse --show-toplevel 2>/dev/null) || exit 0

# dotfiles 自身のセッションでは黙る。作業ツリーが汚れているのは作業中だからで、
# 伝え漏らしではない。cwd はフックの入力 JSON ではなく実行時のものを見る。
here=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ "$here" = "$repo" ] && exit 0

changed=$(git -C "$repo" status --porcelain --untracked-files=all 2>/dev/null) || exit 0
[ -n "$changed" ] || exit 0

n=$(printf '%s\n' "$changed" | wc -l | tr -d ' ')
files=$(printf '%s\n' "$changed" | head -8 | sed 's/^/- /')
more=$([ "$n" -gt 8 ] && echo "（ほか $((n - 8)) 件）" || echo "")

python3 -c '
import json, sys
print(json.dumps({"systemMessage": sys.argv[1]}, ensure_ascii=False))
' "dotfiles に未コミットの変更が ${n} 件あります。前のセッションが編集して伝え漏らした可能性があります。
${files}
${more}
このセッションの作業と無関係なら、dotfiles の担当セッションへ知らせるか、ユーザーへ 1 行伝えてください（ask_before_editing_claude_assets.md）。自分でコミットはしない（no_auto_commit.md）"
exit 0
