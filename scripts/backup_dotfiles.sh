#!/bin/sh
set -e

. "$(dirname "$0")/lib.sh"

cd "$DOTFILES_DIR"

if [ ! -d private ]; then
  echo "private/ がありません" >&2
  exit 1
fi

if ! command -v gpg >/dev/null 2>&1; then
  echo "gpg がありません。brew install gnupg してください" >&2
  exit 1
fi

# private/ が実体なので、~ から集め直す必要はない
rm -f "$PRIVATE_ARCHIVE"
tar czf - \
  --exclude '.DS_Store' \
  --exclude 'private/.ssh/agent' \
  --exclude 'private/.config/iterm2/sockets' \
  --exclude '*/cache/*' --exclude '*/Cache/*' --exclude '*/logs/*' --exclude '*.log' \
  private | gpg_encrypt > "$PRIVATE_ARCHIVE"

chmod 600 "$PRIVATE_ARCHIVE"

echo "👍 プライベート dotfiles のバックアップが完了しました: $PRIVATE_ARCHIVE"
echo "   $(du -h "$PRIVATE_ARCHIVE" | cut -f1) / AES-256 で暗号化済み"
echo "   復号にはパスフレーズが必要です。パスワードマネージャへ保管してください"
