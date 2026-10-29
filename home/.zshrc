#
# oh-my-posh
#

eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/config.omp.json)"

#
# zsh の設定
#
# Prezto を外したので、効いていたオプション・エイリアス・キーバインドを明示的に持つ
. ~/.config/zsh/options.zsh

# エイリアス。プラグインより前に読み、Prezto のころと同じ位置にする
. ~/.zsh_aliases/main.zsh

# プラグイン。宣言は ~/.config/sheldon/plugins.toml
#
# compinit を挟んで 2 段階で読む。fpath を足すもの（zsh-completions）は前、
# ウィジェットを扱うもの（fzf-tab 以下）は後でないと成立しない。
# profiles で pre / post に分けている。
#
# 未取得だと source が空になるので、その場合だけ案内を出す。
# ここで入力を求めるとシェルの起動が止まる
if ! eval "$(sheldon --profile pre source 2>/dev/null)"; then
  print -P '%F{yellow}sheldon: プラグインが未取得です。`sheldon lock` を実行してください%f'
fi

autoload -Uz compinit
compinit -C

# fzf-tab は compinit の後、ウィジェットを包む 2 本より前に入る必要がある
eval "$(sheldon --profile post source 2>/dev/null)"

# 補完の見せ方。fzf-tab を読み込んだ後でないと zstyle が効かない
[[ -r ~/.config/zsh/completion.zsh ]] && . ~/.config/zsh/completion.zsh

# キーバインドはプラグインの後。ウィジェットが定義されてからでないと結び付かない
[[ -r ~/.config/zsh/keybindings.zsh ]] && . ~/.config/zsh/keybindings.zsh

# ツールの初期化
. ~/.config/zsh/tools.zsh

# fzf を使うキー操作。ツールのキー操作（atuin の ^r など）とは別のキーに結ぶ
. ~/.config/zsh/widgets.zsh

# 自分で書いた関数
. ~/.config/zsh/functions.zsh

# PATH は最後に組む。ツールの初期化が足した分より前に、自分の置き場を並べるため
. ~/.config/zsh/path.zsh
