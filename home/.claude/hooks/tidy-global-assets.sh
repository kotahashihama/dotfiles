#!/bin/bash
#
# グローバル資産を編集したときに、整理を促す PostToolUse フック。
#
# **編集の仕方では判定しない。** かつて matcher を `Write|Edit` にしていたが、
# auto mode はファイル変更も Bash で行うよう指示するため実質発火しなかった
# （12 時間で 25 ファイル編集して 0 回）。作業ツリーの状態で見れば経路に依存しない。
#
# ただし作業ツリーは複数セッションで共有されるので、状態だけで見ると
# **他セッションの編集まで拾う**（実際に別リポジトリのセッションで鳴った）。
# Write / Edit なら対象パスが入力に入っているのでそれを使い、Bash では
# 「直前に書かれたか」を mtime で絞る。
#
# 同じファイルで何度も鳴らさない。セッション単位で、促したパスを控える。
#
set -u

MTIME_WINDOW=20   # 秒。これより古い変更は他セッターの仕業とみなす

payload=$(cat)
read -r sid edited <<EOF
$(printf '%s' "$payload" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(d.get("session_id", "-"), d.get("tool_input", {}).get("file_path", "-"))
' 2>/dev/null)
EOF
[ -n "${sid:-}" ] && [ "$sid" != "-" ] || exit 0

link=$(readlink "$HOME/.claude/settings.json" 2>/dev/null) || exit 0
[ -n "$link" ] || exit 0
repo=$(git -C "$(dirname "$link")" rev-parse --show-toplevel 2>/dev/null) || exit 0

changed=$(git -C "$repo" status --porcelain --untracked-files=all -- \
  home/.claude/rules home/.claude/skills home/.claude/hooks home/.claude/CLAUDE.md home/.claude/settings.json \
  2>/dev/null | awk '{print $NF}')
[ -n "$changed" ] || exit 0

state="${TMPDIR:-/tmp}/claude-tidy-${sid}.seen"
touch "$state"

now=$(date +%s)
fresh=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -qxF "$f" "$state" 2>/dev/null && continue

  # Write / Edit はパスが分かる。Bash は mtime で「直前に書かれたか」を見る
  if [ "$edited" != "-" ]; then
    case "$edited" in *"${f##*/}") : ;; *) continue ;; esac
  else
    m=$(stat -f %m "$repo/$f" 2>/dev/null || stat -c %Y "$repo/$f" 2>/dev/null) || continue
    [ $((now - m)) -le "$MTIME_WINDOW" ] || continue
  fi

  printf '%s\n' "$f" >> "$state"
  fresh="${fresh}${f}|"
done <<< "$changed"
[ -n "$fresh" ] || exit 0

python3 - "$fresh" <<'PY'
import json, sys

files = [f for f in sys.argv[1].split("|") if f]

CHECKS = [
    ("/rules/", "**ルール**: 分割（1 ファイル 2 主題）/ マージ（同じ主題が散っている）/ 削除（無くても挙動が変わらない・既定に入った・**自分が実行できない**）/ 横断（skills や CLAUDE.md にルールへ引き上げるべき規定が無いか）"),
    ("/skills/", "**スキル**: 分割（1 スキルが複数の責務）/ マージ（同じ手順が重複、委譲で解けないか）/ 整合（委譲先の手順を自前で再定義していないか、相互参照が実態と合うか）/ 横断（固有でない規定が混ざっていないか）"),
    ("/hooks/", "**フック**: 実物の入力で 1 回通したか（自分で組み立てた入力だけでは形の食い違いに気づけない）/ 誤検知の範囲は狭いか / 出力は additionalContext か（systemMessage は Claude に届かない）"),
    ("CLAUDE.md", "**CLAUDE.md**: rules と重複していないか（CLAUDE.md は前提、rules は規約）/ 指す先が実在するか"),
    ("settings.json", "**settings.json**: フックの参照先が実在し実行可能か / 発火条件が広すぎないか / 「毎回やる」と書いてある処理をフックへ寄せられないか"),
]

hit = [c for key, c in CHECKS if any(key in f for f in files)]
if not hit:
    raise SystemExit

shown = ", ".join(files[:5]) + (f" ほか {len(files) - 5} 件" if len(files) > 5 else "")
msg = (
    f"グローバル資産を編集しました（{shown}）。"
    "**この編集を契機に棚卸しまで済ませてください**"
    "（rule_conventions.md / align_skill_md_format.md の「整理の契機」）。\n"
    + "\n".join("- " + c for c in hit)
    + "\n整理が不要と判断した場合も、確認した旨を報告してください。"
)

print(json.dumps({
    "hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": msg},
}, ensure_ascii=False))
PY
exit 0
