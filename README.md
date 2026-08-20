# kotahashihama's dotfiles

macOS 用の個人設定。**そのまま使わないでください。**

自分の環境（1 台の macOS、特定のリポジトリ構成、独自の Claude Code 資産）に合わせてあり、
**中身を読まずに適用すると既存の設定が置き換わります**。参考にするなら、`home/` の個別ファイルか
`scripts/` の仕組みを読んで、必要な部分だけ取ってください。

## 考え方

**運び方で置き場を決める。** 何が秘密かではなく、git で運べるか暗号化アーカイブが要るかで
`home/` と `private/` に分かれる。判断が「表を見る」に変わり、追加のたびに迷わない。

**壊れる経路は既存マシンでは通らない。** リストアが走るのは何も無いマシンなので、手元で動いた
ことは検証にならない。偽の HOME を作って通しで流す（`verify_restore.sh`）。

**強制は機械に、判断は人に。** 秘匿値の混入は `pre-commit` が止める。何をコミットするか、
いつ push するかは自分で決める。

**古いものは捨てる。** 後継が定着したら移り、旧側は設定・`Brewfile`・実体の 3 つから消す。

## 構成

**旧マシンから新マシンへ何で運ぶか**で 2 つの置き場に分かれる。詳細は [`docs/placement.md`](docs/placement.md)。

| 呼び方 | ディレクトリ | 運び方 | 中身 |
| --- | --- | --- | --- |
| **public** | `home/` | **git リポジトリ** | シェル・エディタ・Claude Code の設定 |
| **private** | `private/` | **暗号化アーカイブ** | `.aws` `.ssh` `.config` `.secrets`、業務・自宅向けのエイリアス、Claude の学習メモリ |

`~` 側は実体を持たず、両方からシンボリックリンクを張る。**編集はこのリポジトリの中で完結する。**

## パスフレーズについて

> [!IMPORTANT]
> **パスフレーズを失うと復号できない。** `.ssh` の秘密鍵・クラウドの資格情報・API キーが
> まとめて失われ、**復旧の手段は無い**。生成時に 1 度だけ表示されるので、その場で保管する。

`private/` は AES-256 で暗号化して運ぶ。

| いつ | 何が起きるか |
| --- | --- |
| **バックアップ時** | スクリプトが 32 文字を生成し、**1 度だけ画面に表示する** |
| **リストア時** | `gpg` が対話でパスフレーズを求める |

- **表示されたらすぐパスワードマネージャへ保管する。** ファイルには書き出されない
- **アーカイブとは別の場所に保管する。** 同じクラウドへ置くと、片方が漏れた時点で両方漏れる
- **バックアップはエージェント経由で走らせない。** 生成されたパスフレーズが会話ログに残る

## バックアップ手順

```sh
cd ~/Documents/repositories/github.com/kotahashihama/dotfiles/

# 1. 環境の変化を取り込み、状態を点検する
./scripts/sync_dotfiles.sh

# 2. 管理対象に加えたいものがあれば取り込む
./scripts/adopt_dotfile.sh private .codex/config.toml

# 3. 差分を確認してコミット & push

# 4. private/ を暗号化アーカイブに固める（パスフレーズが表示される）
./scripts/backup_dotfiles.sh

# 5. ~/Desktop/private_dotfiles.tar.gz.gpg をクラウドへアップロード
#    パスフレーズは別の場所へ
```

## リストア手順

**何度流しても同じ結果になる。** 途中で失敗したら、直してからもう一度流せばよい。1 回目に実体が
あれば `dotfiles-salvaged-*` へ退避してから張り、**2 回目以降は退避が起きない**（`verify_restore.sh`
の「冪等性」節が、終了コード・リンク先・退避の有無・リンク数の 4 点を検査する）。


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

# 4. リストアスクリプトを実行（途中でパスフレーズを聞かれる）
./scripts/restore_osx.sh
./scripts/restore_dotfiles.sh
./scripts/restore_languages.sh

# 5. zsh プラグインを取得
sheldon lock

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

アーカイブが手元に無い場合も publicだけリンクして進む。`private/.secrets/env` には雛形が置かれるので、値はパスワードマネージャから入れる。

## スクリプト

| スクリプト | 役割 |
| --- | --- |
| `sync_dotfiles.sh` | Brewfile と mise の一覧を実態へ更新し、宣言とリンクの整合を点検する。**日常的に走らせるのはこれ** |
| `backup_dotfiles.sh` | 下記の書き出しを走らせ、`private/` を AES-256 で暗号化したアーカイブに固める |
| `backup_osx.sh` | macOS の `defaults` 16 ドメインと、インストール済みアプリの一覧を書き出す |
| `backup_associations.sh` | 拡張子とアプリの関連付けを書き出す（`duti`） |
| `backup_keyboard.sh` | キーボードのテキスト置換を書き出す |
| `restore_dotfiles.sh` | アーカイブを復号し、`home/` と `private/` を `~` へリンクする |
| `adopt_dotfile.sh` | `~` 配下のファイルを管理下へ移し、リンクを張り直す |
| `restore_osx.sh` | macOS の設定を適用し、書き出した `defaults` と関連付けを取り込む |
| `restore_languages.sh` | mise の宣言をすべて入れる（言語ランタイムと、gopls / golangci-lint 等の Go ツール） |
| `lib.sh` | 上記が共有する定義とヘルパー |
| `verify_restore.sh` | バックアップ → リストアを偽の HOME で通しで流す（79 項目） |
| `git-hooks/pre-commit` | 公開側への認証情報・非公開の固有名の混入を止める |

## シェルのキー操作

導入しているツールは `Brewfile` と `private/.config/mise/config.toml` が持つ。ここに書くのは
**設定を読まないと分からないもの**だけ。

| キー | 何が起きるか |
| --- | --- |
| `^r` | 履歴を検索する（atuin）。ディレクトリ・終了コード・日時で絞れる |
| `^X^R` | 履歴を検索する（fzf）。atuin へ `^r` を譲ったので退避 |
| `^q` | 最近のディレクトリへ移動する（cdr） |
| `^g` | ghq が管理するリポジトリへ移動する |
| `^t` | gwq が管理する worktree へ移動する |
| `^e` | git のブランチを切り替える |

`^q` `^g` `^t` `^e` は右側にプレビューが出る。`cd` は zoxide が置き換えており、**よく行く場所は
部分名で飛べる**。明示的なパス指定は従来どおり。

zsh の設定は `home/.config/zsh/` に 3 分割してある（`options` / `utility` / `keybindings`）。
プラグインは `home/.config/sheldon/plugins.toml`。

## Claude Code の資産

`~/.claude` は管理対象と管理外（セッション・キャッシュ）が同居するため、**子要素を個別にリンクする**。

| 資産 | 置き場 |
| --- | --- |
| `CLAUDE.md` `rules/` `hooks/` `settings.json` `statusline-command.sh` `agents/` `output-styles/` | `home/.claude/` |
| `CLAUDE.private.md`、非公開の固有名を含むスキル | `private/.claude/` |
| `skills/` | **1 本ずつ置き場が違う**。編集前に `readlink -f` で実体を確かめる |
| 自動メモリ（`projects/<repo>/memory/`） | `private/.claude-memory/` |
| `deny-patterns.txt`（`pre-commit` の検出パターン） | `private/.claude/`。パターン自体が固有名なので公開側に置けない |

`commands/` は [skills に統合済み](https://code.claude.com/docs/en/skills)のため管理しない。

## 点検と検証

このリポジトリを触るときに使うスキル。

| 場面 | スキル |
| --- | --- |
| `~` の設定を管理下へ入れる / 外す | `/adopt-dotfile` |
| コミット・push の前 | `/audit-secrets` |
| 管理下の設定が壊れていないか見る | `/audit-dotfiles [shell\|claude\|brew\|links\|secrets]` |
| `scripts/` や置き場の構成を変えた後 | `/verify-restore` |

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

## 困ったとき

| 症状 | 原因 |
| --- | --- |
| `zsh -i -c` で `gitstatus failed to initialize` が出る | **非対話シェル特有**。実端末では出ない。Powerlevel10k の内部で、設定の問題ではない |
| `> file` が「cannot overwrite」で失敗する | `unsetopt CLOBBER` が効いている（`home/.config/zsh/options.zsh`）。上書きは `>|` |
| `cp` / `mv` / `rm` が確認を求める | `-i` を付けている。確認なしなら `command cp` か `cpf` / `mvf` / `rmf` |
| `brew bundle` が cask で止まる | 手動で入れたアプリが brew 管理外。`brew install --cask --adopt <name>` で取り込む |
| リストア後にリンクが片側しか無い | 両側に持つディレクトリを `PARTIAL_DIRS` へ登録していない（`scripts/lib.sh`） |
| `sheldon: プラグインが未取得です` と出る | `sheldon lock` を実行する |

## 留意事項

- `brew` でインストールした実行ファイルのパスは Apple Silicon か否かで違う
- 適宜 `exec zsh` でシェルをリフレッシュする
- **このリポジトリは public。`home/` に置いたものは全世界から読める**
