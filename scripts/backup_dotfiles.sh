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

# macOS の設定を書き出してからアーカイブに含める。別途叩く形にすると
# 書き出しが古いまま固められる。
sh "$(dirname "$0")/backup_osx.sh"
sh "$(dirname "$0")/backup_associations.sh"
sh "$(dirname "$0")/backup_keyboard.sh"

# パスフレーズはこちらで生成する。人が決めると弱くなり、二重入力も要る。
# 検証用に PRIVATE_PASSPHRASE を渡した場合はそれを使う。
GENERATED=0
if [ -z "${PRIVATE_PASSPHRASE:-}" ]; then
  PRIVATE_PASSPHRASE=$(openssl rand -base64 24 | tr -d '\n')
  GENERATED=1
fi
export PRIVATE_PASSPHRASE

# private/ が実体なので、~ から集め直す必要はない
rm -f "$PRIVATE_ARCHIVE"
tar czf - \
  --exclude '.DS_Store' \
  --exclude 'private/.ssh/agent' \
  --exclude 'private/.config/iterm2/sockets' \
  --exclude '*/cache/*' --exclude '*/Cache/*' --exclude '*/logs/*' --exclude '*.log' \
  `# ツールが再取得できる実体。設定ではないので運ばない` \
  --exclude 'private/.config/tfenv/versions' \
  --exclude 'private/.config/raycast/extensions' \
  --exclude 'private/.config/gcloud/virtenv' \
  `# 実行時の状態。設定は defaults 側で持つ` \
  --exclude 'private/.config/iterm2/AppSupport' \
  --exclude '__pycache__' --exclude '*.pyc' \
  private | gpg_encrypt > "$PRIVATE_ARCHIVE"

chmod 600 "$PRIVATE_ARCHIVE"

echo "👍 プライベート dotfiles のバックアップが完了しました"
echo "   ${PRIVATE_ARCHIVE} / $(du -h "$PRIVATE_ARCHIVE" | cut -f1) / AES-256"

if [ "$GENERATED" -eq 1 ]; then
  # 復号に必要なので一度だけ見せる。アーカイブと同じ場所に置くと
  # 両方まとめて漏れるため、ファイルには書き出さない。
  cat <<MSG

--- パスフレーズ（この 1 回だけ表示します）---

    $PRIVATE_PASSPHRASE

--------------------------------------------

  1. パスワードマネージャへ保管する
  2. アーカイブとは別の場所に保管する。同じクラウドへ置くと、
     片方が漏れた時点で両方漏れる
  3. 失うと復号できない。アーカイブは復元不能になる
MSG
fi
