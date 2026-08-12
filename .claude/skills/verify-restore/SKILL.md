---
description: 偽の HOME を作って backup → restore を通しで流し、新規マシンでリストアが成立するかを実測する。scripts/ や層構成を変更した直後に使う。ユーザーが「リストアを検証して」「新規マシンで動くか確かめて」「/verify-restore」等を指示したときに使う。
allowed-tools: Bash(mkdir:*) Bash(rm:*) Bash(cp:*) Bash(rsync:*) Bash(ls:*) Bash(readlink:*) Bash(find:*) Bash(unzip:*) Bash(zsh:*) Bash(sh:*) Bash(printf:*) Bash(chmod:*)
---

`scripts/restore_dotfiles.sh` は**何も無いマシンで走る**のが本番。既存マシンでは `ln` が File exists で黙って失敗して素通りするため、壊れる経路を通らない。詳細は `.claude/rules/restore-verification.md`。

## 進め方

1. **作業場所を用意する**: スクラッチパッド配下に `fakehome` と `bin` を作る。`~` は絶対に触らない

2. **リポジトリを複製する**: `rsync -a --exclude '.git' --exclude '*.sock' --exclude 'agent/' --exclude 'sockets/'` で本物をコピーする。ソケットは複製できずエラーになる

3. **backup を流す**: 環境変数で行き先を差し替える

   ```sh
   PRIVATE_ARCHIVE=$SIM/priv.tar.gz.gpg PRIVATE_PASSPHRASE=testpass DOTFILES_DIR=$SIM/repo \
     sh scripts/backup_dotfiles.sh
   ```

   アーカイブが GPG 形式で、展開後のトップレベルが `private` になっていることを確認する（`file -b` と `tar tzf`）

4. **新規マシンを再現する**: 複製から `private/` を削除する。`git clone` 直後の状態になる

5. **`brew` を stub して restore を流す**: `printf '#!/bin/sh\necho "[stub] brew $*"\n'` で置き、`PATH` の先頭に足す

   ```sh
   PATH=$SIM/bin:$PATH HOME=$SIM/fakehome DOTFILES_DIR=$SIM/repo \
     PRIVATE_ARCHIVE=$SIM/priv.tar.gz.gpg PRIVATE_PASSPHRASE=testpass sh scripts/restore_dotfiles.sh
   ```

6. **4 点を確認する**

   | 観点 | 確認方法 |
   | --- | --- |
   | リポジトリが無傷か | `$SIM/repo/home` と `private` の実体が読めるか。`Too many levels of symbolic links` が出ないか |
   | リンク先が正しいか | `readlink` で `~/.zsh_aliases` が public、`~/.zsh_aliases_private` が private を指すか |
   | 部分リンクが効いているか | `~/.claude` `~/.codex` `~/.cursor` が実体ディレクトリで、子要素がリンクか |
   | 秘匿値なしで起動するか | `HOME=$SIM/fakehome zsh -ic` でシェルが立ち上がり、主要エイリアスが引けるか |

7. **後片付け**: 偽 HOME を削除する

## 出力の目安

観点ごとに合否を示し、リンクは**リンク元 → リンク先**の形で並べる。失敗したら、どの手順のどの行が原因かまで書く。

```markdown
| 観点 | 結果 |
| --- | --- |
| リポジトリの実体 | 無傷 |
| リンク先 | .zsh_aliases -> home/, .zsh_aliases_private -> private/ |
| 部分リンク | .claude 配下 5 件すべて子要素リンク |
| 秘匿値なしの起動 | 起動 OK、cldpr / ssml / gst すべて定義済み |
```

## やってはいけないこと

- 本物の `~` に対して restore を流すこと
- 既存マシンで動いたことを根拠に「検証済み」と報告すること
- `private/` を削除する手順を飛ばすこと。**既に private/ がある状態で流すと、壊れる経路を通らない**
- `PRIVATE_PASSPHRASE` を手作業で使うこと。**検証専用**で、`ps` とシェル履歴に残る
- `~/.gnupg` が偽 HOME に作られるのを異常として扱うこと。gpg が復号時に自分で作る
- 検証で作った偽 HOME を消さずに残すこと
