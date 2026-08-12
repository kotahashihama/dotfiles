#!/bin/sh
# Claude Code statusLine command — 4-line layout
#
# Line 1: 📂 full path (HOME shortened to ~)
# Line 2: 🐙 repo name │ 🌿 branch [+N ~M]  (omitted outside git)
# Line 3: 🧠 progress bar used% │ 💪 model name
# Line 4: 💰 5h X% (🔄 Xam) │ 7d X% (🔄 M/DD Xam)  (omitted when absent)

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
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd="$PWD"

model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# ---------------------------------------------------------------------------
# Line 1 — Current path (HOME → ~)
# ---------------------------------------------------------------------------
display_path=$(printf '%s' "$cwd" | sed "s|^${HOME}|~|")
printf "%s\n" "📂 ${WHITE}${display_path}${RESET}"

# ---------------------------------------------------------------------------
# Line 2 — Repo & Branch (only inside a git repo)
# ---------------------------------------------------------------------------
toplevel=$(timeout 1 git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$toplevel" ]; then
  repo_name=$(basename "$toplevel")
  branch=$(timeout 1 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(timeout 1 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

  # Count diff: +N (staged) ~M (unstaged modifications), tracked files only
  added=$(timeout 1 git -C "$cwd" diff --cached --name-only 2>/dev/null | grep -c .)
  modified=$(timeout 1 git -C "$cwd" diff --name-only 2>/dev/null | grep -c .)

  diff_part=""
  if [ "$added" -gt 0 ] || [ "$modified" -gt 0 ]; then
    branch_color="${YELLOW}"
    [ "$added" -gt 0 ] && diff_part=" ${GREEN}+${added}${RESET}"
    [ "$modified" -gt 0 ] && diff_part="${diff_part} ${YELLOW}~${modified}${RESET}"
  else
    branch_color="${GREEN}"
  fi

  printf "%s\n" "🐙 ${WHITE}${repo_name}${RESET} │ 🌿 ${branch_color}${branch}${RESET}${diff_part}"
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

printf "%s\n" "🧠 ${bar_color}${bar}${RESET} ${used_int}% │ 💪 ${WHITE}${model}${RESET}"

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
