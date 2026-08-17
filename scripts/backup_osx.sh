#!/bin/sh
#
# 実機の defaults を書き出す。新マシンへ現状をそのまま持っていくため。
#
set -e

. "$(dirname "$0")/lib.sh"

# ドメイン一覧はこのスクリプトと同じ場所に置く。DOTFILES_DIR は書き出し先の
# 指定なので、そちらを基準にすると検証で差し替えたときに見つからなくなる。
DOMAINS_FILE="$(cd "$(dirname "$0")" && pwd)/osx-domains.txt"
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

# 入れ直せば済むものは一覧だけ持っていく。実体を運ぶより軽く、腐らない。
INV="$DOTFILES_DIR/private/.inventory"
mkdir -p "$INV"
command -v mas    >/dev/null 2>&1 && mas list                      > "$INV/mas.txt"           2>/dev/null
command -v code   >/dev/null 2>&1 && code --list-extensions        > "$INV/vscode.txt"        2>/dev/null
command -v cursor >/dev/null 2>&1 && cursor --list-extensions      > "$INV/cursor.txt"        2>/dev/null
command -v npm    >/dev/null 2>&1 && npm ls -g --depth=0 --parseable 2>/dev/null | tail -n +2 | sed 's|.*/||' > "$INV/npm-global.txt"
command -v mise   >/dev/null 2>&1 && mise ls --current             > "$INV/mise.txt"          2>/dev/null

echo "   インストール済みの一覧を書き出しました: $(ls -A "$INV" | tr '\n' ' ')"
exit 0
