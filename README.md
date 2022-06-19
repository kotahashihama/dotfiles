# kotahashihama's dotfiles

現状、ドットファイルと `Brewfile` を置くのみ  
`install.sh` を書いて自動化したい

## やること

- Homebrew を入れる
- `Brewfile` から依存パッケージをインストール
- asdf プラグインを入れる
- `.gitignore` 記載のディレクトリ・ファイルを非 git 経由で持ってくる
- シンボリックリンクを貼る

```sh
# Homebrew 入れたあとに実行
echo 'eval $(/opt/homebrew/bin/brew shellenv)' >> ~/.zprofile
eval $(/opt/homebrew/bin/brew shellenv)
```
