#!/bin/sh
#
# キーボードのテキスト置換を書き出す。
#
# 実体は ~/Library/KeyboardServices/TextReplacements.db（SQLite）にあり、
# defaults からは触れない。iCloud 同期が有効なら新マシンでは自動で戻るが、
# 同期を切っている場合と、iCloud ごと失った場合の控えとして持っておく。
#
# 書き戻しは DB を直接書き換えることになり壊しやすいので、この一覧を見ながら
# 手で入れ直す前提にする。14件程度なら数分で終わる。
#
set -e

. "$(dirname "$0")/lib.sh"

DB=~/Library/KeyboardServices/TextReplacements.db
DEST="$DOTFILES_DIR/private/.keyboard"

[ -f "$DB" ] || { echo "   テキスト置換のデータベースがありません。飛ばします"; exit 0; }
command -v sqlite3 >/dev/null 2>&1 || { echo "   sqlite3 がありません。飛ばします"; exit 0; }

mkdir -p "$DEST"
if sqlite3 "$DB" \
  "select ZSHORTCUT, ZPHRASE from ZTEXTREPLACEMENTENTRY where ZSHORTCUT is not null order by ZSHORTCUT;" \
  > "$DEST/text-replacements.tsv" 2>/dev/null; then
  echo "👍 テキスト置換を書き出しました: $(wc -l < "$DEST/text-replacements.tsv" | tr -d ' ')件"
else
  echo "   テキスト置換を読み取れませんでした。飛ばします"
  rm -f "$DEST/text-replacements.tsv"
fi
