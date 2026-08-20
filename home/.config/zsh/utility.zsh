#
# Prezto の utility から引き継いだもの
#
# 84 個あったうち、実際に効くものだけを残した。落としたのは
# 使っていないツール向け（ebuild / bower / rake / heroku / ftp / gist / ack）、
# macOS 以外のプラットフォーム向け（cygstart / termux / xclip）、
# eza へ置き換えた ls 系。

# 打ち間違いの指摘（CORRECT）を、引数がパスになるコマンドでは黙らせる
alias cp='nocorrect cp'
alias mv='nocorrect mv'
alias rm='nocorrect rm'
alias ln='nocorrect ln'
alias mkdir='nocorrect mkdir'
alias grep='nocorrect grep --color=auto'
alias man='nocorrect man'
alias mysql='nocorrect mysql'

# グロブを展開させたくないもの
alias find='noglob find'
alias rsync='noglob rsync'
alias scp='noglob scp'
alias history='noglob history'

# 上書き・削除の前に確認する。-i を外したいときは command cp のように呼ぶ
alias cp="${aliases[cp]:-cp} -i"
alias mv="${aliases[mv]:-mv} -i"
alias ln="${aliases[ln]:-ln} -i"
alias rm="${aliases[rm]:-rm} -i"
alias mkdir="${aliases[mkdir]:-mkdir} -p"

# 確認なしで実行したいとき用
alias cpf='command cp'
alias mvf='command mv'
alias rmf='command rm'

# 素の ls にも色を付ける。一覧は eza の ll / lt を使う
alias ls='ls -G'

# 短縮
alias _='sudo'
alias o='open'
alias pbc='pbcopy'
alias pbp='pbpaste'
alias -- -='cd -'
for i in {1..9}; do alias "$i"="cd +$i"; done
unset i
alias po='popd'
alias pu='pushd'
alias sa='alias | grep -i'
alias diffu='diff --unified'
alias df='df -kh'
alias du='du -kh'
alias http-serve='python3 -m http.server'
