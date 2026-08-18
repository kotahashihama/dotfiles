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

# Windsurf
alias ws='windsurf'
alias ws.='ws .'

# Docker
alias d='docker'
alias dc='docker-compose'
alias dce='dc exec $1'
alias dcu='dc up -d'
alias dcun='dc build --no-cache && dcu'
alias dcd='dc down -v'
alias dcl='dc logs'
alias dii='d image inspect'
alias dci='d container inspect'
alias dvi='d volume inspect'
alias dni='d network inspect'
alias dbls='dc down --rmi all --volumes'

# Terraform
alias tf='terraform'
alias tfi='tf init'
alias tfp='tf plan'
alias tfa='tf apply'

# Git
. ~/.zsh_aliases/tool/git.zsh

# Claude Code
alias cld='claude'
alias cldr='cld -r'
alias cldrc='claude remote-control'

# Anthropic Computer Use
alias computeruse='echo "最後に表示される案内文がどうであれ、http://localhost:8050 でホストされることに注意してください。" \
    && docker run \
    -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
    -v $HOME/.anthropic:/home/computeruse/.anthropic \
    -p 5900:5900 \
    -p 8501:8501 \
    -p 6080:6080 \
    -p 8050:8080 \
    -it ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest'

