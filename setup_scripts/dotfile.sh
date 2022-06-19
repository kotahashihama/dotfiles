#!/bin/sh

install_asdf() {
  brew install asdf

  # Ruby
  asdf plugin-add ruby
  asdf install ruby 3.1.2
  asdf global ruby 3.1.2

  # Node.js
  asdf plugin-add nodejs
  asdf install nodejs 18.3.0
  asdf global nodejs 18.3.0
  npm -g i yarn pnpm
  npm -g i commitizen cz-conventional-changelog-ja

  # Go
  asdf plugin-add golang
  asdf install golang 1.18
  asdf global golang 1.18

  # Python
  asdf plugin-add python
  asdf install python 3.10.5
  asdf global python 3.10.5
}

setup_dotfiles() {
  install_asdf

  # Homebrew 依存パッケージのインストール
  brew bundle

  # ホームディレクトリへシンボリックリンクを貼る
  for dotfile in $(ls -A home); do
    ln -sf ~/Documents/repositories/github.com/kotahashihama/dotfiles/home/$dotfile ~
  done

  echo "👍 ドットファイルのセットアップが完了しました"
}

setup_dotfiles
