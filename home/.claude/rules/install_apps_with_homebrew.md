# アプリと CLI は Homebrew で入れ、Brewfile へ足す

Mac に入れるアプリと CLI は、Homebrew の cask と formula で入れてください。入れたら dotfiles の `Brewfile` にも同じ行を足します。
これは全プロジェクト共通の規約です。

```sh
brew info --cask <name>      # cask があるか（アプリ）
brew info <name>             # formula があるか（CLI）
brew install --cask <name>   # 入れる
```

**公式サイトの dmg やインストーラのスクリプトより先に、cask と formula を探す。** Homebrew で入れれば、更新・削除・一覧が `brew` 1つで済みます。

## Brewfile へ足す

入れただけでは新しいマシンに来ません。`Brewfile` は新しいマシンを作るときの一覧なので、載っていないものは復元されません。

| 足すもの | 書き方 |
| --- | --- |
| 説明の行 | `brew desc` の1行をコメントで置く（ `# AI note-taking for ...` ） |
| 本体の行 | `cask "<name>"` か `brew "<name>"` |
| 置く位置 | 同じ種類の中で名前の順 |

消すときは、`brew uninstall` と `Brewfile` からの削除を一緒に行います。片方だけだと、手元か新しいマシンのどちらかに残ります。

## 対象外

| もの | 扱い |
| --- | --- |
| Homebrew に無いもの | 公式の手段で入れ、何で入れたかをユーザーへ伝える |
| リポジトリの依存（ `package.json` ・ `go.mod` ） | そのリポジトリのパッケージマネージャで入れる |
| `gh` の拡張 | `gh extension install` で入れる。`Brewfile` には載らない |

## なぜ

- 入れ方が1つなら、何が入っているかを `brew list` と `Brewfile` の2か所で見られる。dmg で入れたアプリはどちらにも出ず、更新も手で追うことになる
- `Brewfile` に無いものは新しいマシンで抜け落ちる。気づくのは、使おうとして無いと分かったとき

## 例外

- ユーザーが入れ方を指定した場合

## 関連

- `manage_repositories_with_ghq.md` （リポジトリは ghq の配置で作る）: 同じ形。置き場をツールに決めさせ、一覧から漏らさない
- `write_for_installed_versions.md` （入っているバージョンで書く）: 入れた後に、何が入っているかを確かめる側
- `install_plugins_with_auto_update.md` （外部のスキルはプラグインで入れる）: 同じ形で、Claude Code のプラグイン。あちらは自動更新まで定める
