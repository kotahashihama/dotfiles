#!/bin/sh
# Claude Code statusLine command — 4-line layout
#
# Line 1: 🐙 repo[/subpath] │ 🌿 branch [+N ~M] [│ 🌳 worktree]
#         (📂 full path instead, when outside a git repo)
# Line 2: 🧠 progress bar used% │ 🤖 model · effort · output style
# Line 3: 💰 5h X% (🔄 Xam) │ 7d X% (🔄 M/DD Xam)  (omitted when absent)

input=$(cat)

# ---------------------------------------------------------------------------
# Escape / color setup
# ---------------------------------------------------------------------------
ESC=$(printf '\033')
RESET="${ESC}[0m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
RED="${ESC}[31m"
WHITE="${ESC}[37m"
CYAN="${ESC}[36m"
GRAY="${ESC}[90m"

# ---------------------------------------------------------------------------
# Shared data from JSON
# ---------------------------------------------------------------------------
# macOS には timeout が無い。無ければ付けずに走らせる（ローカルの git は速い）
if command -v timeout >/dev/null 2>&1; then
  TMO="timeout 1"
elif command -v gtimeout >/dev/null 2>&1; then
  TMO="gtimeout 1"
else
  TMO=""
fi

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd="$PWD"

model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# 既定ではどこにも出ないもの。jq は1回にまとめ、cut で切り出す
extra=$(echo "$input" | jq -r '[
  (.effort.level // ""), (.output_style.name // ""), (.worktree.name // "")
] | @tsv')
effort=$(printf '%s' "$extra" | cut -f1)
out_style=$(printf '%s' "$extra" | cut -f2)
wt_name=$(printf '%s' "$extra" | cut -f3)

# ---------------------------------------------------------------------------
# Line 1 — Location
#
# リポジトリの中では 🐙 が repo 名を持つので、フルパスを別行で出すと末尾が
# 重複する。repo + その中の相対パスに畳み、フルパスは repo の外でだけ出す
# ---------------------------------------------------------------------------
toplevel=$($TMO git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)

if [ -n "$toplevel" ]; then
  # worktree では --show-toplevel が worktree 自身を返す。本体の名前は
  # --git-common-dir（本体の .git を指す）から辿る
  common=$($TMO git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  if [ -n "$common" ]; then
    repo_name=$(basename "$(dirname "$common")")
  else
    repo_name=$(basename "$toplevel")
  fi

  sub=${cwd#"$toplevel"}
  sub=${sub#/}
  [ -n "$sub" ] && repo_name="${repo_name}/${sub}"

  branch=$($TMO git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$($TMO git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

  # Count diff: +N (staged) ~M (unstaged modifications), tracked files only
  added=$($TMO git -C "$cwd" diff --cached --name-only 2>/dev/null | grep -c .)
  modified=$($TMO git -C "$cwd" diff --name-only 2>/dev/null | grep -c .)

  diff_part=""
  if [ "$added" -gt 0 ] || [ "$modified" -gt 0 ]; then
    branch_color="${YELLOW}"
    [ "$added" -gt 0 ] && diff_part=" ${GREEN}+${added}${RESET}"
    [ "$modified" -gt 0 ] && diff_part="${diff_part} ${YELLOW}~${modified}${RESET}"
  else
    branch_color="${GREEN}"
  fi

  # worktree の中は本体とパスが似ている。別ツリーを編集する事故を防ぐため
  # 末尾に 🌳 を出す。名前はブランチから読み取れるなら省く（同じ語が2度並ぶ）
  wt_part=""
  if [ -n "$wt_name" ]; then
    case "$branch" in
      *"$wt_name"*) wt_part=" │ 🌳" ;;
      *) wt_part=" │ 🌳 ${CYAN}${wt_name}${RESET}" ;;
    esac
  fi

  printf "%s\n" "🐙 ${WHITE}${repo_name}${RESET} │ 🌿 ${branch_color}${branch}${RESET}${diff_part}${wt_part}"
else
  display_path=$(printf '%s' "$cwd" | sed "s|^${HOME}|~|")
  printf "%s\n" "📂 ${WHITE}${display_path}${RESET}"
fi

# ---------------------------------------------------------------------------
# Line 3 — Context bar & Model
# ---------------------------------------------------------------------------
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
else
  used_int=0
fi

# Build 15-block progress bar
filled=$(( used_int * 15 / 100 ))
[ "$filled" -gt 15 ] && filled=15
empty=$(( 15 - filled ))

bar=""
i=0
while [ "$i" -lt "$filled" ]; do
  bar="${bar}█"
  i=$(( i + 1 ))
done
i=0
while [ "$i" -lt "$empty" ]; do
  bar="${bar}░"
  i=$(( i + 1 ))
done

# Color the bar based on usage
if [ "$used_int" -ge 80 ]; then
  bar_color="${RED}"
elif [ "$used_int" -ge 50 ]; then
  bar_color="${YELLOW}"
else
  bar_color="${GREEN}"
fi

# effort と出力スタイルは応答の形を変えるが、既定ではどこにも出ない
mode_part=""
[ -n "$effort" ] && mode_part="${mode_part} ${GRAY}· ${effort}${RESET}"
[ -n "$out_style" ] && mode_part="${mode_part} ${GRAY}· ${out_style}${RESET}"

printf "%s\n" "🧠 ${bar_color}${bar}${RESET} ${used_int}% │ 🤖 ${WHITE}${model}${RESET}${mode_part}"

# ---------------------------------------------------------------------------
# Line 4 — Rate limits (omit entirely if both are absent)
# ---------------------------------------------------------------------------
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$five_pct" ] || [ -n "$seven_pct" ]; then
  # Helper: pick color for a usage percentage value
  _rate_color() {
    _pct=$(printf "%.0f" "$1")
    if [ "$_pct" -ge 80 ]; then
      printf '%s' "${RED}"
    elif [ "$_pct" -ge 50 ]; then
      printf '%s' "${YELLOW}"
    else
      printf '%s' "${GREEN}"
    fi
  }

  five_part=""
  if [ -n "$five_pct" ]; then
    five_int=$(printf "%.0f" "$five_pct")
    five_col=$(_rate_color "$five_pct")
    if [ -n "$five_resets" ]; then
      # Format as hour + am/pm, e.g. "4am" or "10pm"
      reset_hour=$(date -r "$five_resets" +%I%p 2>/dev/null \
                 | sed 's/^0//' | tr '[:upper:]' '[:lower:]')
      five_part="${five_col}5h ${five_int}% (🔄 ${reset_hour})${RESET}"
    else
      five_part="${five_col}5h ${five_int}%${RESET}"
    fi
  fi

  seven_part=""
  if [ -n "$seven_pct" ]; then
    seven_int=$(printf "%.0f" "$seven_pct")
    seven_col=$(_rate_color "$seven_pct")
    if [ -n "$seven_resets" ]; then
      # Format as M/DD HHam/pm, e.g. "3/13 10am"
      reset_md=$(date -r "$seven_resets" +'%-m/%d' 2>/dev/null)
      reset_hm=$(date -r "$seven_resets" +%I%p 2>/dev/null \
               | sed 's/^0//' | tr '[:upper:]' '[:lower:]')
      seven_part="${seven_col}7d ${seven_int}% (🔄 ${reset_md} ${reset_hm})${RESET}"
    else
      seven_part="${seven_col}7d ${seven_int}%${RESET}"
    fi
  fi

  # Assemble line 4
  if [ -n "$five_part" ] && [ -n "$seven_part" ]; then
    printf "%s\n" "💰 ${five_part} │ ${seven_part}"
  elif [ -n "$five_part" ]; then
    printf "%s\n" "💰 ${five_part}"
  else
    printf "%s\n" "💰 ${seven_part}"
  fi
fi
