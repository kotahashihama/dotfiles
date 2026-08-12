#!/bin/sh
#
# 実機の defaults を書き出す。新マシンへ現状をそのまま持っていくため。
#
set -e

. "$(dirname "$0")/lib.sh"

DOMAINS_FILE="$DOTFILES_DIR/scripts/osx-domains.txt"
DEST="$DOTFILES_DIR/private/.macos-defaults"

[ -f "$DOMAINS_FILE" ] || { echo "$DOMAINS_FILE がありません" >&2; exit 1; }

mkdir -p "$DEST"
exported=0
skipped=''

while IFS= read -r domain; do
  case "$domain" in ''|'#'*) continue ;; esac
  if defaults export "$domain" "$DEST/$domain.plist" 2>/dev/null; then
    exported=$((exported + 1))
  else
    skipped="$skipped $domain"
    rm -f "$DEST/$domain.plist"
  fi
done < "$DOMAINS_FILE"

# 一覧から消えたドメインの書き出しが残らないようにする
for f in "$DEST"/*.plist; do
  [ -f "$f" ] || continue
  d=$(basename "$f" .plist)
  grep -qxF "$d" "$DOMAINS_FILE" || { rm -f "$f"; echo "   除去: $d（一覧に無い）"; }
done

echo "👍 macOS の設定を書き出しました: $exported ドメイン / $(du -sh "$DEST" | cut -f1)"
[ -n "$skipped" ] && echo "   未設定のため飛ばした:$skipped"
exit 0
