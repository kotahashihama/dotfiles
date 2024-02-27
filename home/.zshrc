# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"

#
# zplug
#
export ZPLUG_HOME=/usr/local/opt/zplug
. $ZPLUG_HOME/init.zsh

# プラグイン
zplug "sorin-ionescu/prezto"
zplug "marzocchi/zsh-notify"

# Prezto のプラグイン
zplug "modules/environment", from:prezto
zplug "modules/terminal", from:prezto
zplug "modules/editor", from:prezto
zplug "modules/history", from:prezto
zplug "modules/directory", from:prezto
zplug "modules/spectrum", from:prezto
zplug "modules/utility", from:prezto
zplug "modules/completion", from:prezto
zplug "modules/history-substring-search", from:prezto
zplug "modules/syntax-highlighting", from:prezto
zplug "modules/autosuggestions", from:prezto
zplug "modules/prompt", from:prezto

# プラグインがなければインストール
if ! zplug check --verbose; then
  printf 'Install? [y/N]: '
  if read -q; then
    echo; zplug install
  fi
fi

#
# zsh-nofity
#
. /usr/local/opt/zplug/repos/marzocchi/zsh-notify/notify.plugin.zsh
zstyle ':notify:*' error-title "Command failed (in #{time_elapsed} seconds)"
zstyle ':notify:*' success-title "Command finished (in #{time_elapsed} seconds)"
zstyle ':notify:*' error-sound "Glass"
zstyle ':notify:*' success-sound "default"
zstyle ':notify:*' command-complete-timeout 5

# GitHub Copilot CLI
eval "$(github-copilot-cli alias -- "$0")"

#
# Powerlevel10k
#

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  . "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  . "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || . ~/.p10k.zsh

#
# peco
#

# history (Ctrl + R)
function peco-history-selection() {
  BUFFER=`history -n 1 | tail -r | awk '!a[$0]++' | peco --prompt "❯"`
  CURSOR=$#BUFFER
  zle reset-prompt
}
zle -N peco-history-selection
bindkey '^r' peco-history-selection

# cdr (Ctrl + E)
if [[ -n $(echo ${^fpath}/chpwd_recent_dirs(N)) && -n $(echo ${^fpath}/cdr(N)) ]]; then
  autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
  add-zsh-hook chpwd chpwd_recent_dirs
  zstyle ':completion:*' recent-dirs-insert both
  zstyle ':chpwd:*' recent-dirs-default true
  zstyle ':chpwd:*' recent-dirs-max 1000
  zstyle ':chpwd:*' recent-dirs-file "$HOME/.cache/chpwd-recent-dirs"
fi

function peco-cdr() {
  local selected_dir="$(cdr -l | sed 's/^[0-9]* *//' | peco --prompt "❯" --query "$LBUFFER")"
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
}
zle -N peco-cdr
bindkey '^q' peco-cdr

# ghq (Ctrl + G)
function peco-src() {
  local selected_dir=$(ghq list -p | peco --prompt "❯" --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
}
zle -N peco-src
bindkey '^g' peco-src

# git branch (Ctrl + E)
function peco-git-branch() {
  git checkout $(git branch | sed "s/*//g" | sed "s/ //g" | peco)
}
zle -N peco-git-branch
bindkey '^e' peco-git-branch

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

#
# mise
#
eval "$(/usr/local/bin/mise activate zsh)"

#
# pnpm
#
export PNPM_HOME="~/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Dart
export PATH="$PATH":"$HOME/.pub-cache/bin"

#
# エイリアス
#
. ~/.zsh_aliases/main.zsh

#
# シェルオプション
#
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


# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"
