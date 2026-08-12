# kotahashihama's dotfiles

## 構成

ファイルは 3 つの層に分かれる。詳細は [`docs/layers.md`](docs/layers.md)。

| 層 | 置き場 | git | zip | 中身 |
| --- | --- | --- | --- | --- |
| **public** | `home/` | 追跡する | 含めない | シェル・エディタ・Claude Code の設定 |
| **private** | `private/` | 追跡しない | 含める | `.aws` `.ssh` `.config`、業務・自宅向けのエイリアス |
| **secret** | `~/.secrets/env` | 追跡しない | **含めない** | API キー・トークンの値 |

`~` 側は実体を持たず、両方の層へシンボリックリンクを張る。**編集はこのリポジトリの中で完結する。**

## バックアップ手順

```sh
cd ~/Documents/repositories/github.com/kotahashihama/dotfiles/

# 1. Brewfile を更新
mv Brewfile Brewfile.old && brew bundle dump

# 2. 管理対象に加えたいものがあれば取り込む
./scripts/adopt_dotfile.sh private .codex/config.toml

# 3. コミット & push

# 4. private/ を zip に固める
./scripts/backup_dotfiles.sh

# 5. ~/Desktop/private_dotfiles.zip をクラウドへアップロード
```

秘匿値 (`~/.secrets/env`) は zip に含まれない。**パスワードマネージャ側で管理する。**

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

# 4. Prezto をインストール
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"

# 5. リストアスクリプトを実行
./scripts/restore_osx.sh
./scripts/restore_dotfiles.sh
./scripts/restore_languages.sh

# 6. ~/.secrets/env に値を入れる（雛形が置かれている）
```

リンク先に実体があった場合は削除せず `~/dotfiles-salvaged-<日時>/` へ退避する。**リストアが既存の設定を消すことはない。**

## スクリプト

| スクリプト | 役割 |
| --- | --- |
| `backup_dotfiles.sh` | `private/` を zip に固める |
| `restore_dotfiles.sh` | zip を展開し、`home/` と `private/` を `~` へリンクする |
| `adopt_dotfile.sh` | `~` 配下のファイルを管理下へ移し、リンクを張り直す |
| `restore_osx.sh` | macOS の各種設定を書き込む |
| `restore_languages.sh` | mise で言語ランタイムを入れる |
| `lib.sh` | 上記が共有する定義とヘルパー |
| `git-hooks/pre-commit` | 公開層への認証情報・社内固有名の混入を止める |

## 手動で設定する必要があるもの

- AltTab
- Raycast
- gh
- `~/.secrets/env` の値（パスワードマネージャから）

## 留意事項

- `brew` でインストールした実行ファイルのパスは Apple Silicon か否かで違う
- 適宜 `zsh` でシェルをリフレッシュする
- **このリポジトリは public。`home/` に置いたものは全世界から読める**
