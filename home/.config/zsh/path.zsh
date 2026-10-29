#
# PATH
#
# 上に書いたものほど先に探す。-U で重複を落とすので、入れ子のシェルでも同じ並びになる
export PNPM_HOME="$HOME/Library/pnpm"
export BUN_INSTALL="$HOME/.bun"
typeset -U path
path=(
  # Claude Code は起動スクリプト経由で起動する（autoMode の信頼先を --settings で渡すため。~/.claude/bin/claude）
  "$HOME/.claude/bin"
  "$HOME/.local/bin"
  /Applications/Devin.app/Contents/Resources/app/bin
  "$BUN_INSTALL/bin"
  "$PNPM_HOME"
  $path
)
