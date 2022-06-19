# kotahashihama's dotfiles

## 手順

```sh
# 1. Homebrew の前提となる Command Line Tools for Xcode をインストール
xcode-select --install

# 2. Homebrew をインストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval $(/opt/homebrew/bin/brew shellenv)

# 3. `kotahashihama/dotfiles` をクローン
brew install git
mkdir -p ~/Documents/repositories/github.com/kotahashihama/
cd ~/Documents/repositories/github.com/kotahashihama/
git clone git@github.com:kotahashihama/dotfiles.git
cd dotfiles

# 4. `.gitignore` 記載のディレクトリ＆ファイルをローカルリポジトリ内へ含める

# 5. セットアップスクリプトを実行
./setup.sh
```
