#
# fzf
#

# history (Ctrl + X Ctrl + R)
# ^r は atuin が使う。fzf 版は補助として残す
function fzf-history-selection() {
  BUFFER=$(history -n 1 | tail -r | awk '!a[$0]++' | fzf --prompt "❯ ")
  CURSOR=$#BUFFER
  zle reset-prompt
}
zle -N fzf-history-selection
bindkey '^X^R' fzf-history-selection

# cdr (Ctrl + Q)
if [[ -n $(echo ${^fpath}/chpwd_recent_dirs(N)) && -n $(echo ${^fpath}/cdr(N)) ]]; then
  autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
  add-zsh-hook chpwd chpwd_recent_dirs
  zstyle ':completion:*' recent-dirs-insert both
  zstyle ':chpwd:*' recent-dirs-default true
  zstyle ':chpwd:*' recent-dirs-max 1000
  zstyle ':chpwd:*' recent-dirs-file "$HOME/.cache/chpwd-recent-dirs"
fi

function fzf-cdr() {
  # cdr -l は ~/... 形式で返す。表示はそのまま、プレビューには展開後を渡す
  local selected=$(cdr -l | sed 's/^[0-9]* *//' \
    | awk -v h="$HOME" '{ p = $0; sub(/^~/, h, p); print $0 "\t" p }' \
    | fzf --prompt "❯ " --query "$LBUFFER" \
      --delimiter '\t' --with-nth 1 \
      --preview 'ls -lAh -- {2}' \
      --preview-window 'right,50%')
  local selected_dir=$(printf '%s' "$selected" | cut -f1)
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
}
zle -N fzf-cdr
bindkey '^q' fzf-cdr

# ghq (Ctrl + G)
function fzf-src() {
  # 候補は ghq list（github.com/owner/repo）で出す。-p はどれも同じ接頭辞が
  # 付くぶん幅を食い、絞り込みのノイズにもなる
  local selected=$(ghq list | fzf --prompt "❯ " --query "$LBUFFER" \
    --preview 'cd "$(ghq root)" && git -C {} log --oneline --decorate -15 --color=always' \
    --preview-window 'right,60%')
  if [ -n "$selected" ]; then
    BUFFER="cd $(ghq root)/${selected}"
    zle accept-line
  fi
}
zle -N fzf-src
bindkey '^g' fzf-src

# gwq worktree (Ctrl + T)
function fzf-worktree() {
  # リポジトリ内にいればそこの worktree を、外なら gwq が管理する分を出す。
  # --global は basedir しか見ないので、git 側で作った worktree が漏れる
  local json=$(gwq list --json 2>/dev/null)
  case "$json" in
    \[*) ;;
    *) json=$(gwq list --global --json 2>/dev/null) ;;
  esac
  # どちらでも取れなければ JSON ではなくメッセージが返っている
  case "$json" in
    \[*) ;;
    *) zle -M "worktree がありません（gwq add -b <branch> で作る）"; return ;;
  esac

  # 表示はブランチと ~ 短縮したパス。置き場の形が gwq と git で違うため、
  # パスの一部を切り出す形だと意味を成さない
  local gitroot=$(git rev-parse --show-toplevel 2>/dev/null)
  local selected=$(printf '%s' "$json" \
    | jq -r --arg h "$HOME" --arg r "${gitroot:-/dev/null}" '
        .[] | select(.is_main | not)
        | "\(.branch)\t\(.path | sub("^" + $r + "/"; "") | sub("^" + $h; "~"))\t\(.path)"' \
    | fzf --prompt "❯ " --query "$LBUFFER" \
      --delimiter '\t' --with-nth 1,2 \
      --preview 'git -C {3} log --oneline --decorate -15 --color=always' \
      --preview-window 'right,60%')
  if [ -n "$selected" ]; then
    BUFFER="cd $(printf '%s' "$selected" | cut -f3)"
    zle accept-line
  fi
}
zle -N fzf-worktree
bindkey '^t' fzf-worktree

# git branch (Ctrl + E)
function fzf-git-branch() {
  local selected_branch=$(git branch --format='%(refname:short)' | fzf --prompt "❯ " \
    --preview 'git log --oneline --decorate -15 --color=always {}' \
    --preview-window 'right,60%')
  if [ -n "$selected_branch" ]; then
    git switch "$selected_branch"
  fi
}
zle -N fzf-git-branch
bindkey '^e' fzf-git-branch
