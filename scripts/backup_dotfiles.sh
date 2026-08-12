#!/bin/sh
set -e

. "$(dirname "$0")/lib.sh"

cd "$DOTFILES_DIR"

if [ ! -d private ]; then
  echo "private/ がありません" >&2
  exit 1
fi

# private/ が実体なので、~ から集め直す必要はない
rm -f "$PRIVATE_ZIP"
zip -rqy "$PRIVATE_ZIP" private \
  -x '*.DS_Store' \
  -x 'private/.ssh/agent/*' \
  -x 'private/.config/iterm2/sockets/*' \
  -x '*/cache/*' -x '*/Cache/*' -x '*/logs/*' -x '*.log'

echo "👍 プライベート dotfiles のバックアップが完了しました: $PRIVATE_ZIP"
echo "   秘匿値 (~/.secrets/env) は含まれません。パスワードマネージャ側で管理してください"
