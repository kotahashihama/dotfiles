# dotfiles

macOS の設定ファイル一式。`~` 側は実体を持たず、このリポジトリへシンボリックリンクを張る。**編集はリポジトリ内で完結する。**

`CLAUDE.md` は置かない。スキルの実体は `.claude/skills/` にあり、`.agents/skills/` に同じものへのリンクを置いている。ルールの実体は `.claude/rules/` にある。Claude Code 以外のエージェントはルールを自動で読み込まないので、作業に関わるものを開いて従う（ `~/.claude/rules/agent_config.md` ）。

## まず読むもの

| 知りたいこと | 場所 |
| --- | --- |
| 置き場の定義・選び方・秘匿値の切り出し方 | [`docs/placement.md`](docs/placement.md) |
| **フックが何を弾くか・なぜ弾かないか** | [`docs/hooks.md`](docs/hooks.md) |
| バックアップ / リストアの手順 | [`README.md`](README.md) |

## 古いものは捨てて、新しいものへ乗り換える

**更新が止まったツールを抱え続けない。** 後継が定着していれば移る。実際に `peco` → `fzf`、`zplug` → `sheldon` と入れ替えている。

**乗り換えたら、旧側は消すところまでが1セット。**

| やること | なぜ |
| --- | --- |
| 設定から参照を消す | 残っていると、次に読む人がどちらが現役か分からない |
| `Brewfile` から外す | 新マシンで復活する |
| **`brew uninstall` する** | 手元に残っていると、消したつもりで動き続ける |
| **`scripts/restore_dotfiles.sh` から導入の処理を消す** | 新マシンで復活する。**しかも失敗として出ない**（ `npx` や `npm` が無い環境では黙って飛ばす作りなので、気づけるのは新マシンで実物を見たときだけ） |

**使わなくなった formula も同じ。** 前職の案件・終了した学習・後継に置き換えたもの。気づいたら
**見立てを添えて尋ねる**（ `.claude/skills/audit-dotfiles` の「役目を終えたものを見分ける」）。

**判断材料は会話にしかない。** 「もう使っていない」はファイルから読み取れないので、**推測で消さない**。

## アプリと CLI は Homebrew に乗せ、管理する範囲は定期的に見直す

**cask か formula があるものは、Homebrew で入れて Brewfile に載せる。** 公式サイトの dmg やインストーラで入れたものも、`brew install --cask --adopt` で取り込む。Brewfile に無いものは、新しいマシンに入らない。

**管理する設定と、管理しないものを定期的に見直す。** 手で書いた設定はリンクにして管理し、キャッシュ・状態・ログ・認証情報は外す。見直しの手順は `/audit-dotfiles` の brew と links の種別が持つ。

## このリポジトリは GitHub 上で public

`home/` と `scripts/` に置いたものは全世界から読める。**追加・移動の前に置き場を決める**（ `.claude/rules/file-placement.md` ）。

API キーなどの秘匿値は 1Password の Environment 「dotfiles」に置き、使うコマンドを `with-secrets` 経由で起動する。設定ファイルには変数名の参照だけを残す。サービスアカウントのトークンはマシンごとにキーチェーンへ入れる（リストアのスクリプトが手順を出す）。

公開側への混入は `scripts/git-hooks/pre-commit` が止める。新しい社内固有名は `private/.claude/deny-patterns.txt` へ足す。

## 作業の型

| 場面 | 使うもの |
| --- | --- |
| `~` の設定を管理下へ入れる / 外す | `/adopt-dotfile` （手動起動のみ） |
| コミット・push の前 | `/audit-secrets` |
| `scripts/` や置き場の構成を変えた後 | `/verify-restore` |
| 管理下の設定が壊れていないか見る | `/audit-dotfiles [種別]` |

`scripts/` を変えたら**偽の HOME で実測してから確定する**。既存マシンでは壊れる経路を通らない（ `.claude/rules/restore-verification.md` ）。
