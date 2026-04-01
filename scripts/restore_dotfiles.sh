#!/bin/sh

brew bundle

DOTFILES_DIR=~/Documents/repositories/github.com/kotahashihama/dotfiles

# プライベート dotfiles を解凍して home/ に配置
unzip -o ~/Desktop/private_dotfiles.zip -d ~/Desktop/
cp -r ~/Desktop/private_dotfiles/ $DOTFILES_DIR/home/
rm -rf ~/Desktop/private_dotfiles/ ~/Desktop/private_dotfiles.zip

for dotfile in $(ls -A home); do
  ln -sf $DOTFILES_DIR/home/$dotfile ~
done

# ディレクトリ内の個別ファイルをリンク
mkdir -p ~/.claude
ln -sf $DOTFILES_DIR/home/.claude/settings.json ~/.claude/settings.json

echo "👍 dotfiles のリストアが完了しました"
