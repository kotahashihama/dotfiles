#!/bin/sh

cd ~/Desktop/
mkdir private_dotfiles/
cd private_dotfiles/

cp -r ~/.aws .aws/
cp -r ~/.ssh .ssh/

cp -r ~/.zsh_aliases .zsh_aliases/
cp -r ~/.zsh_scripts .zsh_scripts/

cd ../
zip -r private_dotfiles.zip private_dotfiles/

echo "👍 プライベート dotfiles のバックアップが完了しました"
