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

# Markdown を検査するフックの依存を入れる。lockfile があるので npm ci で揃う
if command -v npm >/dev/null 2>&1; then
  (cd "$DOTFILES_DIR/home/.claude/hooks/textlint" && npm ci --silent) \
    || echo "⚠️  textlint の導入に失敗しました。Markdown の検査フックは黙って通ります"
fi

# 同じフックが使う suiko。版と sha256 は install.sh の隣に固定してある
bash "$DOTFILES_DIR/home/.claude/hooks/suiko/install.sh" >/dev/null \
  || echo "⚠️  suiko の導入に失敗しました。Markdown の検査は textlint だけで動きます"

# gh の拡張。Brewfile は本体しか運ばないので、ここで入れる。
# 新規マシンでは認証が先なので、通っていなければ案内だけ出して飛ばす
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  for ext in dlvhdr/gh-dash github/gh-stack; do
    gh extension install "$ext" >/dev/null 2>&1 \
      || echo "⚠️  $ext の導入に失敗しました"
  done
elif command -v gh >/dev/null 2>&1; then
  echo "ℹ️  gh の認証がまだです。gh auth login のあとで gh extension install を実行してください"
fi

# 外部のスキル。実体は ~/.agents 配下に入るのでこのリポジトリでは運ばない。
# ~/.claude/skills へリンクが張られるところまでインストーラがやる
if command -v npx >/dev/null 2>&1; then
  for skill in coji/natural-japanese; do
    [ -e "$HOME/.agents/skills/${skill#*/}" ] && continue
    npx --yes skills add "$skill" >/dev/null 2>&1 \
      || echo "⚠️  $skill の導入に失敗しました"
  done
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

report_links

if [ -n "$DRY_RUN" ]; then
  echo "🔎 DRY_RUN のため何も変更していません。実行するなら DRY_RUN を外してください"
else
  echo "👍 dotfiles のリストアが完了しました"
fi
