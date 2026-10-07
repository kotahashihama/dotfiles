#!/bin/bash
#
# ~/.claude/skills/ の各スキルを、Codex が読む ~/.agents/skills/ へリンクで渡す。
#
# 実体は Claude Code の側に置き、ほかのエージェントにはリンクで同じものを渡す
# （home/.claude/rules/agent_config.md）。スキルを足すたび・消すたびに流してよい。
#
# - リンクは相対パス（../../.claude/skills/<名前>）で張る。$HOME の位置に依らない
# - ~/.agents/skills/<名前> に実体（npx skills で入れたもの）があれば触らない
# - このスクリプトが張ったリンクのうち、先が消えたものは外す
#
set -u

home=${HOME:?}
src="$home/.claude/skills"
dst="$home/.agents/skills"

[ -d "$src" ] || exit 0
mkdir -p "$dst"

linked=0 kept=0 removed=0

for entry in "$src"/*; do
  [ -e "$entry" ] || continue
  name=$(basename "$entry")
  target="../../.claude/skills/$name"
  link="$dst/$name"
  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$target" ] && continue
    rm -f "$link"
  elif [ -e "$link" ]; then
    kept=$((kept + 1))
    continue
  fi
  ln -s "$target" "$link"
  linked=$((linked + 1))
done

# 先が消えたリンクを外す。外すのはこのスクリプトが張った形のものだけ
for link in "$dst"/*; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    ../../.claude/skills/*) [ -e "$link" ] || { rm -f "$link"; removed=$((removed + 1)); } ;;
  esac
done

echo "~/.agents/skills: 新しく張った ${linked} 本・実体があるので残した ${kept} 本・外した ${removed} 本"
