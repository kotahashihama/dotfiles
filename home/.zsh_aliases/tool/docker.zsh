# Docker
alias d='docker'
alias dc='docker compose'
alias dce='dc exec'
alias dcu='dc up -d'
alias dcun='dc build --no-cache && dcu'
alias dcd='dc down -v'
alias dcl='dc logs'
alias dii='d image inspect'
alias dci='d container inspect'
alias dvi='d volume inspect'
alias dni='d network inspect'
# コンテナに加えて、イメージとボリュームまで消す
alias dcda='dc down --rmi all --volumes'
