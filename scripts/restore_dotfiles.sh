#!/bin/sh

brew bundle

for dotfile in $(ls -A home); do
  ln -sf ~/Documents/repositories/github.com/kotahashihama/dotfiles/home/$dotfile ~
done

echo "👍 プライベート dotfiles のリストアが完了しました"
