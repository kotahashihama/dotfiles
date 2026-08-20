# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

#
# Powerlevel10k
#

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  . "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# テーマ本体。Prezto の prompt モジュール経由をやめ、brew の実体を直接読む
. "$(brew --prefix powerlevel10k)/share/powerlevel10k/powerlevel10k.zsh-theme"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || . ~/.p10k.zsh

#
# zsh の設定
#
# Prezto を外したので、効いていたオプション・エイリアス・キーバインドを明示的に持つ
for f in options utility; do
  [[ -r ~/.config/zsh/$f.zsh ]] && . ~/.config/zsh/$f.zsh
done

# プラグイン。宣言は ~/.config/sheldon/plugins.toml
# 未取得だと source が空になるので、その場合だけ案内を出す。
# ここで入力を求めると Powerlevel10k の instant prompt と競合する
if ! eval "$(sheldon source 2>/dev/null)"; then
  print -P '%F{yellow}sheldon: プラグインが未取得です。`sheldon lock` を実行してください%f'
fi

# 補完系。プラグインが fpath へ入った後で compinit を走らせる必要がある
autoload -Uz compinit
compinit -C

# キーバインドはプラグインの後。ウィジェットが定義されてからでないと結び付かない
[[ -r ~/.config/zsh/keybindings.zsh ]] && . ~/.config/zsh/keybindings.zsh

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# direnv
eval "$(direnv hook zsh)"

# Docker
source <(docker completion zsh)

#
# fzf
#

# history (Ctrl + R)
function fzf-history-selection() {
  BUFFER=$(history -n 1 | tail -r | awk '!a[$0]++' | fzf --prompt "❯ ")
  CURSOR=$#BUFFER
  zle reset-prompt
}
zle -N fzf-history-selection
bindkey '^r' fzf-history-selection

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
  local json=$(gwq list --global --json 2>/dev/null)
  # worktree が 1 つも無いと JSON ではなくメッセージが返る
  case "$json" in
    \[*) ;;
    *) zle -M "worktree がありません（gwq add -b <branch> で作る）"; return ;;
  esac

  # 表示は owner/repo と branch、cd には末尾のフルパスを使う
  local selected=$(printf '%s' "$json" \
    | jq -r '.[] | "\(.path | split("/") | .[-3:-1] | join("/"))\t\(.branch)\t\(.path)"' \
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
  local selected_branch=$(git branch | sed "s/*//g" | sed "s/ //g" | fzf --prompt "❯ " \
    --preview 'git log --oneline --decorate -15 --color=always {}' \
    --preview-window 'right,60%')
  if [ -n "$selected_branch" ]; then
    git checkout "$selected_branch"
  fi
}
zle -N fzf-git-branch
bindkey '^e' fzf-git-branch

function create-project() {
  REPO_NAME=$1

  gh repo create $REPO_NAME --private --confirm
  ghq get git@github.com:kotahashihama/$REPO_NAME.git
}

function delete-project() {
  REPO_NAME=$1

  echo -n "本当にリポジトリを削除してよろしいですか？ (Y/n) "
  read -r CONFIRM

  if [ "$CONFIRM" = "Y" ] || [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "" ]; then
    gh repo delete $REPO_NAME --yes
    ghq list --full-path | grep $REPO_NAME | xargs rm -rf
    echo "Repository deleted successfully"
  else
    echo "Deletion cancelled"
  fi
}

# mise
eval "$(/opt/homebrew/bin/mise activate zsh)"

# zoxide
# cd を置き換える。よく行く場所は部分一致で飛べるようになり、
# 明示的なパス指定は今までどおり動く。^q の cdr は履歴順なので役割が違う
eval "$(zoxide init zsh --cmd cd)"

# pnpm
# クォート内の ~ は展開されないため $HOME を使う
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Dart
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Windsurf
export PATH="/Users/kotahashihama/.codeium/windsurf/bin:$PATH"

# Kiro
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# エイリアス
. ~/.zsh_aliases/main.zsh

# シェルオプション
setopt interactive_comments
setopt correct
unsetopt correct_all
setopt noautomenu
setopt histverify
setopt extended_history
setopt magic_equal_subst

#
# AWS
#
set-awssession-token() {
  profile_name=$1
  code=$2

  mfa_device=$(cat ~/.aws/config | grep -A 4 $profile_name | grep mfa-device | cut -f 3 -d " ")
  session_token=$(aws sts get-session-token --serial-number $mfa_device --token-code $code --profile $profile_name)
  export AWS_ACCESS_KEY_ID=$(echo $session_token | jq -r .Credentials.AccessKeyId)
  export AWS_SECRET_ACCESS_KEY=$(echo $session_token | jq -r .Credentials.SecretAccessKey)
  export AWS_SESSION_TOKEN=$(echo $session_token | jq -r .Credentials.SessionToken)
}

release-awssession-token() {
  export -n AWS_ACCESS_KEY_ID
  export -n AWS_SECRET_ACCESS_KEY
  export -n AWS_SESSION_TOKEN
}

# Terraform
export GODEBUG=asyncpreemptoff=1

# Antigravity
[[ -f "$HOME/fig-export/dotfiles/dotfile.zsh" ]] && builtin source "$HOME/fig-export/dotfiles/dotfile.zsh"
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# OpenClaw
[[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"

# uv / rye
[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
