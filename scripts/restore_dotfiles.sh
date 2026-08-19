#!/bin/sh
set -e

. "$(dirname "$0")/lib.sh"

SALVAGE_DIR=~/dotfiles-salvaged-$(date +%Y%m%d%H%M%S)

brew bundle

# 暗号化アーカイブを復号して private/ に配置する
if [ -f "$PRIVATE_ARCHIVE" ]; then
  gpg_decrypt "$PRIVATE_ARCHIVE" | tar xzf - -C "$DOTFILES_DIR"
  chmod 700 "$DOTFILES_DIR/private/.secrets" 2>/dev/null || true
  chmod 600 "$DOTFILES_DIR/private/.secrets/env" 2>/dev/null || true
  rm -f "$PRIVATE_ARCHIVE"
else
  echo "⚠️  $PRIVATE_ARCHIVE が見つかりません。publicのみリンクします"
fi

link_layer home
link_layer private

# Claude Code の自動メモリを ~/.claude/projects/<key>/memory へ戻す。
# 保存先はプロジェクトのパスから導かれるため、ディレクトリ名がそのまま鍵になる。
if [ -d "$DOTFILES_DIR/private/.claude-memory" ]; then
  for mem in "$DOTFILES_DIR"/private/.claude-memory/*; do
    [ -d "$mem" ] || continue
    key=$(basename "$mem")
    mkdir -p ~/.claude/projects/"$key"
    link_into_home "$mem" ~/.claude/projects/"$key"/memory
  done
fi

# Claude Code の managed settings（auto mode の環境情報）を戻す。
# 置き場がシステム領域なので sudo が要る。自動では実行せず、要るときだけ案内する。
MANAGED_SRC="$DOTFILES_DIR/private/.claude/managed-settings.json"
MANAGED_DST="/Library/Application Support/ClaudeCode/managed-settings.json"
if [ -f "$MANAGED_SRC" ] && [ ! -e "$MANAGED_DST" ]; then
  echo "ℹ️  auto mode の環境情報が未配置です。次を実行してください:"
  echo "    sudo mkdir -p \"$(dirname "$MANAGED_DST")\" && sudo ln -sfn \"$MANAGED_SRC\" \"$MANAGED_DST\""
fi

# 公開側への混入を検査するフックを有効にする
if git -C "$DOTFILES_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$DOTFILES_DIR" config core.hooksPath scripts/git-hooks
fi

# アーカイブが無い場合は秘匿値も来ないため、雛形を用意する
if [ ! -f ~/.secrets/env ]; then
  mkdir -p "$DOTFILES_DIR/private/.secrets" && chmod 700 "$DOTFILES_DIR/private/.secrets"
  cp "$DOTFILES_DIR/scripts/secrets.env.example" "$DOTFILES_DIR/private/.secrets/env"
  chmod 600 "$DOTFILES_DIR/private/.secrets/env"
  link_into_home "$DOTFILES_DIR/private/.secrets" ~/.secrets
  echo "⚠️  ~/.secrets/env は雛形です。パスワードマネージャから値を入れてください"
fi

if [ -d "$SALVAGE_DIR" ]; then
  echo "⚠️  リンク先にあった実体を $SALVAGE_DIR へ退避しました"
fi

echo "👍 dotfiles のリストアが完了しました"
