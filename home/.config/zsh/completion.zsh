# 補完の見せ方。fzf-tab が読み込まれた後に効く。

# fzf-tab が曖昧でない接頭辞を捉えられるよう、zsh 標準のメニューを出さない
zstyle ':completion:*' menu no

# グループ名を表示する。エスケープシーケンスは fzf-tab が無視するので使わない
zstyle ':completion:*:descriptions' format '[%d]'

# ファイル名に色を付ける
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# git のブランチは新しい順に並んでいるので、辞書順に並べ替えない
zstyle ':completion:*:git-checkout:*' sort false

# fzf-tab は FZF_DEFAULT_OPTS を読まない。他の fzf 呼び出しと見た目を揃える
zstyle ':fzf-tab:*' fzf-flags --prompt='❯ ' --height=50%

# 選ぶ前に中身を見せる。ディレクトリは一覧、ファイルは先頭を出す
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:*:*' fzf-preview \
  '[[ -d $realpath ]] && eza -1 --color=always $realpath || bat --color=always --style=plain --line-range=:40 $realpath 2>/dev/null'
