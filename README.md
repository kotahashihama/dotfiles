# kotahashihama's dotfiles

## バックアップ手順

```sh
# 1. Brewfile を抽出
cd ~/Documents/repositories/github.com/kotahashihama/dotfiles/
mv Brewfile Brewfile.old
brew bundle dump

# 2. dotfiles で新しく管理したいファイルがあればリポジトリに含める

# 3. コミット＆push しておく

# 4. バックアップスクリプトを実行
./scripts/restore_dotfiles.sh

# 5. private_dotfiles.zip をクラウドにアップロードする
```

## リストア手順

```sh
# 1. クラウドからダウンロードした private_dotfiles.zip をデスクトップに置く

# 2. Homebrew をインストール
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. このリポジトリをクローン
brew install git
mkdir -p ~/Documents/repositories/github.com/kotahashihama/
cd ~/Documents/repositories/github.com/kotahashihama/
git clone git@github.com:kotahashihama/dotfiles.git
cd dotfiles/

# 4. リストアスクリプトを実行
./scripts/restore_osx.sh
./scripts/restore_dotfiles.sh
./scripts/restore_languages.sh
```

## 手動で設定する必要があるもの

- AltTab
- Raycast
- Fig
- gh

## 留意事項

- `brew` でインストールした実行ファイルのパスは Apple Silicon か否かで違う
- 適宜 `zsh` でシェルをリフレッシュする
