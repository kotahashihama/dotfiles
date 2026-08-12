# dotfiles

macOS の設定ファイル一式。`~` 側は実体を持たず、このリポジトリへシンボリックリンクを張る。**編集はリポジトリ内で完結する。**

## まず読むもの

| 知りたいこと | 場所 |
| --- | --- |
| 層の定義・置き場の選び方・秘匿値の切り出し方 | [`docs/layers.md`](docs/layers.md) |
| バックアップ / リストアの手順 | [`README.md`](README.md) |

## このリポジトリは GitHub 上で public

`home/` と `scripts/` に置いたものは全世界から読める。**追加・移動の前に層を決める**（`.claude/rules/layer-placement.md`）。

秘匿値は `~/.secrets/env` に置き、設定ファイルには参照だけを残す。git にも zip にも入らない。

公開層への混入は `scripts/git-hooks/pre-commit` が止める。新しい社内固有名は `private/.claude/deny-patterns.txt` へ足す。

## 作業の型

| 場面 | 使うもの |
| --- | --- |
| `~` の設定を管理下へ入れる / 外す | `/adopt-dotfile`（手動起動のみ） |
| コミット・push の前 | `/audit-secrets` |
| `scripts/` や層構成を変えた後 | `/verify-restore` |
| エイリアス・関数の死活を確認する | `/audit-aliases` |

`scripts/` を変えたら**偽の HOME で実測してから確定する**。既存マシンでは壊れる経路を通らない（`.claude/rules/restore-verification.md`）。
