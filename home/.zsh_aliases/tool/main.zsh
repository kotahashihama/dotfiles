# ファイル一覧・閲覧
# 素の ls / cat は残す。壊れたときに切り分けられなくなる
alias ll='eza -lah --git --icons --group-directories-first'
alias lt='eza --tree --level=2 --icons --git-ignore'
alias b='bat'

# ターミナル
alias -g @tn='| terminal-notifier'

# tmux
alias t='tmux'
alias tls='t ls'
alias tnt='t new -t'
alias tat='t attach -t'
alias tkt='t kill-session -t'

# Vim
alias v='vi'

# Homebrew
alias brl='brew list'
alias bri='brew install'
alias brun='brew uninstall'

# npm
alias npmi='npm i'
alias npmid='npmi -D'
alias npmci='npm ci'
alias npmun='npm un'

# pnpm
alias pnpmi='pnpm i'

# VSCode
alias vs='code'
alias vs.='vs .'

# Cursor
alias cs='cursor'
alias cs.='cs .'

# Devin（旧 Windsurf）
alias dvn='devin-desktop'
alias dvn.='dvn .'

# Terraform
alias tf='terraform'
alias tfi='tf init'
alias tfp='tf plan'
alias tfa='tf apply'
