#!/bin/sh

brew bundle

DOTFILES_DIR=~/Documents/repositories/github.com/kotahashihama/dotfiles

for dotfile in $(ls -A home); do
  ln -sf $DOTFILES_DIR/home/$dotfile ~
done

# ディレクトリ内の個別ファイルをリンク
mkdir -p ~/.claude
ln -sf $DOTFILES_DIR/home/.claude/settings.json ~/.claude/settings.json

echo "👍 dotfiles のリストアが完了しました"
