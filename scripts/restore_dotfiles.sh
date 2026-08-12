#!/bin/sh
set -e

. "$(dirname "$0")/lib.sh"

SALVAGE_DIR=~/dotfiles-salvaged-$(date +%Y%m%d%H%M%S)

brew bundle

# private_dotfiles.zip を展開して private/ 層に配置する
if [ -f "$PRIVATE_ZIP" ]; then
  unzip -oq "$PRIVATE_ZIP" -d ~/Desktop/
  mkdir -p "$DOTFILES_DIR/private"
  cp -R ~/Desktop/private/. "$DOTFILES_DIR/private/"
  rm -rf ~/Desktop/private/ "$PRIVATE_ZIP"
else
  echo "⚠️  $PRIVATE_ZIP が見つかりません。public 層のみリンクします"
fi

link_layer home
link_layer private

# 公開層への混入を検査するフックを有効にする
git -C "$DOTFILES_DIR" config core.hooksPath scripts/git-hooks

# 秘匿値はどちらの層にも入らないため、雛形だけ用意する
if [ ! -f ~/.secrets/env ]; then
  mkdir -p ~/.secrets && chmod 700 ~/.secrets
  cp "$DOTFILES_DIR/scripts/secrets.env.example" ~/.secrets/env
  chmod 600 ~/.secrets/env
  echo "⚠️  ~/.secrets/env は雛形です。パスワードマネージャから値を入れてください"
fi

if [ -d "$SALVAGE_DIR" ]; then
  echo "⚠️  リンク先にあった実体を $SALVAGE_DIR へ退避しました"
fi

echo "👍 dotfiles のリストアが完了しました"
