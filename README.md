# kotahashihama's dotfiles

## 構成

**旧マシンから新マシンへ何で運ぶか**で 2 つの層に分かれる。詳細は [`docs/layers.md`](docs/layers.md)。

| 層 | 置き場 | 運び方 | 中身 |
| --- | --- | --- | --- |
| **public** | `home/` | **git リポジトリ** | シェル・エディタ・Claude Code の設定 |
| **private** | `private/` | **暗号化アーカイブ** | `.aws` `.ssh` `.config` `.secrets`、業務・自宅向けのエイリアス、Claude の学習メモリ |

`~` 側は実体を持たず、両方の層へシンボリックリンクを張る。**編集はこのリポジトリの中で完結する。**

## ⚠️ パスフレーズについて

**`private/` は AES-256 で暗号化して運ぶ。パスフレーズが無いと新マシンで復元できない。**

| いつ | 何が起きるか |
| --- | --- |
| **バックアップ時** | スクリプトが 32 文字を生成し、**1 度だけ画面に表示する** |
| **リストア時** | `gpg` が対話でパスフレーズを求める |

- **表示されたらすぐパスワードマネージャへ保管する。** ファイルには書き出されない
- **アーカイブとは別の場所に保管する。** 同じクラウドへ置くと、片方が漏れた時点で両方漏れる
- **失うと復号できない。** `.ssh` の秘密鍵・クラウドの資格情報・API キーがまとめて失われる
- **バックアップはエージェント経由で走らせない。** 生成されたパスフレーズが会話ログに残る

## バックアップ手順

```sh
cd ~/Documents/repositories/github.com/kotahashihama/dotfiles/

# 1. Brewfile を更新
mv Brewfile Brewfile.old && brew bundle dump

# 2. 管理対象に加えたいものがあれば取り込む
./scripts/adopt_dotfile.sh private .codex/config.toml

# 3. コミット & push

# 4. private/ を暗号化アーカイブに固める（パスフレーズが表示される）
./scripts/backup_dotfiles.sh

# 5. ~/Desktop/private_dotfiles.tar.gz.gpg をクラウドへアップロード
#    パスフレーズは別の場所へ
```

## リストア手順

```sh
# 1. クラウドからダウンロードしたアーカイブをデスクトップに置く
#    ~/Desktop/private_dotfiles.tar.gz.gpg

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

# 5. リストアスクリプトを実行（途中でパスフレーズを聞かれる）
./scripts/restore_osx.sh
./scripts/restore_dotfiles.sh
./scripts/restore_languages.sh

# 6. シェルを読み込み直す
exec zsh
```

### 手で移すもの

dotfiles では運ばない。**新マシンで消えるので、移行前に確認する。**

- [ ] `~/Documents` の作業ファイル（リポジトリは `git clone` で戻る）
- [ ] `~/Desktop` `~/Downloads` に置いたままのもの
- [ ] Keychain（パスワード・証明書）
- [ ] Wi-Fi のパスワード
- [ ] アクセシビリティ / フルディスクアクセスの許可（アプリ起動時に都度）
- [ ] ブラウザのプロファイル（アカウント同期があれば自動）
- [ ] `private/.inventory/` を見て、拡張とアプリを入れ直す

リンク先に実体があった場合は削除せず `~/dotfiles-salvaged-<日時>/` へ退避する。**リストアが既存の設定を消すことはない。**

アーカイブが手元に無い場合も public 層だけリンクして進む。`private/.secrets/env` には雛形が置かれるので、値はパスワードマネージャから入れる。

## スクリプト

| スクリプト | 役割 |
| --- | --- |
| `backup_dotfiles.sh` | 下記の書き出しを走らせ、`private/` を AES-256 で暗号化したアーカイブに固める |
| `backup_osx.sh` | macOS の `defaults` 16 ドメインと、インストール済みアプリの一覧を書き出す |
| `backup_associations.sh` | 拡張子とアプリの関連付けを書き出す（`duti`） |
| `backup_keyboard.sh` | キーボードのテキスト置換を書き出す |
| `restore_dotfiles.sh` | アーカイブを復号し、`home/` と `private/` を `~` へリンクする |
| `adopt_dotfile.sh` | `~` 配下のファイルを管理下へ移し、リンクを張り直す |
| `restore_osx.sh` | macOS の設定を適用し、書き出した `defaults` と関連付けを取り込む |
| `restore_languages.sh` | mise で言語ランタイムを入れる |
| `lib.sh` | 上記が共有する定義とヘルパー |
| `verify_restore.sh` | バックアップ → リストアを偽の HOME で通しで流す（79 項目） |
| `git-hooks/pre-commit` | 公開層への認証情報・非公開の固有名の混入を止める |

## Claude Code の資産

`~/.claude` は管理対象と管理外（セッション・キャッシュ）が同居するため、**子要素を個別にリンクする**。

| 資産 | 層 |
| --- | --- |
| `CLAUDE.md` `rules/` `hooks/` `settings.json` `statusline-command.sh` `agents/` `output-styles/` | `home/.claude/` |
| `CLAUDE.private.md`、非公開の固有名を含むスキル | `private/.claude/` |
| `skills/` | **1 本ずつ層が違う**。編集前に `readlink -f` で実体を確かめる |
| 自動メモリ（`projects/<repo>/memory/`） | `private/.claude-memory/` |
| `deny-patterns.txt`（`pre-commit` の検出パターン） | `private/.claude/`。パターン自体が固有名なので公開層に置けない |

`commands/` は [skills に統合済み](https://code.claude.com/docs/en/skills)のため管理しない。

## 点検と検証

このリポジトリを触るときに使うスキル。

| 場面 | スキル |
| --- | --- |
| `~` の設定を管理下へ入れる / 外す | `/adopt-dotfile` |
| コミット・push の前 | `/audit-secrets` |
| 管理下の設定が壊れていないか見る | `/audit-dotfiles [shell\|claude\|brew\|links\|secrets]` |
| `scripts/` や層構成を変えた後 | `/verify-restore` |

## 引き継げるもの / 引き継げないもの

**引き継げる**（アーカイブに入る）。

| 種類 | 中身 |
| --- | --- |
| システム設定 | Finder・Dock・Spaces・トラックパッド・キーボードショートカット・メニューバー等 |
| **アプリ設定** | iTerm2・Raycast・AltTab・Warp・Arc・Terminal（合わせて 22 ドメイン） |
| 関連付け | 拡張子ごとの既定アプリ 38 件 |
| 一覧 | App Store・VS Code / Cursor の拡張・グローバル npm・mise |
| 自動起動 | 自分で入れた LaunchAgents |

**引き継げない**（SIP 保護下や iCloud 側にあり、`defaults` から触れない）。

| 種類 | どうするか |
| --- | --- |
| Keychain・Wi-Fi パスワード | 新マシンで入れ直す。または移行アシスタント |
| アクセシビリティ・フルディスクアクセスの許可 | アプリ起動時に都度許可する |
| テキスト置換 | iCloud 同期が有効なら自動。無効なら `private/.keyboard/text-replacements.tsv` を見て手で入れる |

## 手動で設定する必要があるもの

- gh の認証（`gh auth login`）
- `private/.secrets/env` の値（アーカイブが無い場合のみ）

AltTab と Raycast の設定は `defaults` で運ぶので、手で入れ直す必要はない（アプリ本体は `Brewfile` から入る）。

## 留意事項

- `brew` でインストールした実行ファイルのパスは Apple Silicon か否かで違う
- 適宜 `exec zsh` でシェルをリフレッシュする
- **このリポジトリは public。`home/` に置いたものは全世界から読める**
