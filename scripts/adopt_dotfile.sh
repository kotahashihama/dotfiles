#!/bin/sh
#
# ~ 配下のファイル / ディレクトリを dotfiles の管理下へ移し、元の位置へリンクを張り直す。
#
#   ./scripts/adopt_dotfile.sh public  .claude/statusline-command.sh
#   ./scripts/adopt_dotfile.sh private .mcp.json
#
set -e

. "$(dirname "$0")/lib.sh"

LAYER=$1
TARGET=$2
SALVAGE_DIR=~/dotfiles-salvaged-$(date +%Y%m%d%H%M%S)

case "$LAYER" in
  public)  DEST_LAYER=home ;;
  private) DEST_LAYER=private ;;
  *) echo "usage: $0 {public|private} <~ からの相対パス>" >&2; exit 1 ;;
esac

[ -n "$TARGET" ] || { echo "対象パスを指定してください" >&2; exit 1; }
# shellcheck disable=SC2088  # 表示用の文字列。実パスは別途展開している
[ -e ~/"$TARGET" ] || { echo "~/$TARGET がありません" >&2; exit 1; }
# shellcheck disable=SC2088  # 表示用の文字列。実パスは別途展開している
[ -L ~/"$TARGET" ] && { echo "~/$TARGET は既にリンクです" >&2; exit 1; }

DEST="$DOTFILES_DIR/$DEST_LAYER/$TARGET"
mkdir -p "$(dirname "$DEST")"
mv ~/"$TARGET" "$DEST"
link_into_home "$DEST" ~/"$TARGET"

echo "👍 $TARGET を $DEST_LAYER 層へ移しました"

case "$DEST_LAYER" in
  home)
    echo "   git 管理対象です。公開して問題ない内容か確認してください"
    ;;
  private)
    parent=$(dirname "$TARGET")
    [ "$parent" != "." ] && ! is_partial "$parent" \
      && echo "   ⚠️  $parent は PARTIAL_DIRS に無いため、リストア時に丸ごとリンクされます。scripts/lib.sh を確認してください"
    ;;
esac

true
