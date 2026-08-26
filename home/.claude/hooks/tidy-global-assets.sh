#!/bin/bash
#
# グローバル資産を編集したときに、整理を促す PostToolUse フック。
#
# **編集の仕方では判定しない。** かつて matcher を `Write|Edit` にしていたが、
# auto mode はファイル変更も Bash で行うよう指示するため実質発火しなかった
# （12時間で25ファイル編集して0回）。作業ツリーの状態で見れば経路に依存しない。
#
# ただし作業ツリーは複数セッションで共有されるので、状態だけで見ると
# **他セッションの編集まで拾う**（別リポジトリのセッションで4回連続で鳴った）。
# mtime で絞っても足りない。編集が続いている間は窓に入り続ける。
#
# **この呼び出しの入力がそのファイルを名指ししているか**で判定する。編集する
# コマンドは必ずパスを含み、無関係なコマンド（`gh pr view` 等）は含まない。
#
# 同じファイルで何度も鳴らさない。セッション単位で、促したパスを控える。
#
set -u

payload=$(cat)
sid=$(printf '%s' "$payload" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null) || exit 0
[ -n "$sid" ] || exit 0

# 入力に現れた文字列すべて（Bash の command、Write/Edit の file_path と中身）
inputs=$(printf '%s' "$payload" | python3 -c '
import sys, json
d = json.load(sys.stdin).get("tool_input", {})
print(" ".join(str(v) for v in d.values()))
' 2>/dev/null) || exit 0
[ -n "$inputs" ] || exit 0

link=$(readlink "$HOME/.claude/settings.json" 2>/dev/null) || exit 0
[ -n "$link" ] || exit 0
repo=$(git -C "$(dirname "$link")" rev-parse --show-toplevel 2>/dev/null) || exit 0

changed=$(git -C "$repo" status --porcelain --untracked-files=all -- \
  home/.claude/rules home/.claude/skills home/.claude/hooks home/.claude/agents \
  home/.claude/CLAUDE.md home/.claude/settings.json \
  2>/dev/null | awk '{print $NF}')
[ -n "$changed" ] || exit 0

state="${TMPDIR:-/tmp}/claude-tidy-${sid}.seen"
touch "$state"

fresh=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -qxF "$f" "$state" 2>/dev/null && continue

  # この呼び出しがそのファイルを名指ししていなければ、他セッションの編集
  case "$inputs" in *"${f##*/}"*) : ;; *) continue ;; esac

  printf '%s\n' "$f" >> "$state"
  fresh="${fresh}${f}|"
done <<< "$changed"
[ -n "$fresh" ] || exit 0

python3 - "$fresh" <<'PY'
import json, sys

files = [f for f in sys.argv[1].split("|") if f]

CHECKS = [
    ("/rules/", "**ルール**: 分割（1ファイル2主題）/ マージ（同じ主題が散っている）/ 削除（無くても挙動が変わらない・既定に入った・**自分が実行できない**）/ 横断（skills や CLAUDE.md にルールへ引き上げるべき規定が無いか）"),
    ("/skills/", "**スキル**: 分割（1スキルが複数の責務）/ マージ（同じ手順が重複、委譲で解けないか）/ 整合（委譲先の手順を自前で再定義していないか、相互参照が実態と合うか）/ 横断（固有でない規定が混ざっていないか）"),
    ("/hooks/", "**フック**: 実物の入力で1回通したか（自分で組み立てた入力だけでは形の食い違いに気づけない）/ 誤検知の範囲は狭いか / 出力は additionalContext か（systemMessage は Claude に届かない）/ 分割（1本が複数の主題を抱えている）/ マージ（同じイベントで同じ入力を見ている）/ 削除（settings.json に登録が無い・検査対象が0件のまま・既定に入った）/ 強制力（止めたいのに PostToolUse に置いていないか。あそこは知らせるだけ）"),
    ("/agents/", "**エージェント**: 削除（呼ばれなくなった・既定の型で足りる）/ 整合（CLAUDE.md の自律起動の方針と合っているか）/ 出力契約が検算できる形か"),
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
