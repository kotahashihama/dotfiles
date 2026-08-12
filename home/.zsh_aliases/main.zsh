# 設定ファイルの編集
alias zshrc='v ~/.zshrc'
alias mainalias='v ~/.zsh_aliases/main.zsh'
alias toolalias='v ~/.zsh_aliases/tool/main.zsh'
alias galias='v ~/.zsh_aliases/tool/git.zsh'
alias prjalias='v ~/.zsh_aliases_private/project.zsh'
alias prvalias='v ~/.zsh_aliases_private/crypto.zsh'
alias smhalias='v ~/.zsh_aliases_private/smart_home.zsh'
alias secrets='v ~/.secrets/env'
alias vimrc='v ~/.vimrc'
alias gvimrc='v ~/.gvimrc'
alias gitconfig='v ~/.gitconfig'

# ディレクトリ・ファイル
alias pathc='pwd | pbcopy && echo 現在のパスがクリップボードにコピーされました'
alias ..2='../..'
alias ..3='../../..'
alias o='open'
alias o.='o .'
alias rm='rm -rf'
alias -g @g='| grep'
alias -g @l='| less'

mkd() {
  mkdir -p "$@" && cd "$@"
}

# 再起動
alias relg='exec $SHELL -l'

#
# 言語・フレームワーク
#

# Go
alias gofmt='go fmt'
alias govet='go vet'

# Ruby
alias rb='ruby'

# Python
alias py='python'

# Laravel
alias pa='php artisan'
alias pam='pa migrate'
alias pas='pa serve --host 0.0.0.0'

# Nuxt.js
alias nuxt='./node_modules/.bin/nuxt'

#
# カテゴリ
#

# 開発ツール
. ~/.zsh_aliases/tool/main.zsh

# 非公開分
[ -f ~/.zsh_aliases_private/main.zsh ] && . ~/.zsh_aliases_private/main.zsh
