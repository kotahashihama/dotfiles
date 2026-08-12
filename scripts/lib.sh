#!/bin/sh
#
# backup / restore が共有する定義とヘルパー。
#

DOTFILES_DIR=${DOTFILES_DIR:-~/Documents/repositories/github.com/kotahashihama/dotfiles}
PRIVATE_ZIP=${PRIVATE_ZIP:-~/Desktop/private_dotfiles.zip}

# 実体が別の物と同居するため、ディレクトリごとではなく子要素を個別にリンクする対象。
# 例: ~/.claude にはセッションやキャッシュも入るので、丸ごとリンクすると巻き込む。
# 両方の層が同じディレクトリへ要素を持ち寄る場合も、ここへ入れて衝突を避ける。
PARTIAL_DIRS='.claude .claude/skills .codex .cursor'

is_partial() {
  for d in $PARTIAL_DIRS; do
    [ "$1" = "$d" ] && return 0
  done
  return 1
}

# リンクを張る。既存の実体があれば消さずに退避する。
link_into_home() {
  src=$1   # リポジトリ内の絶対パス
  dst=$2   # ~ 配下の絶対パス

  if [ -L "$dst" ]; then
    rm -f "$dst"
  elif [ -e "$dst" ]; then
    mkdir -p "$SALVAGE_DIR"
    mv "$dst" "$SALVAGE_DIR/"
    echo "  退避: $dst -> $SALVAGE_DIR/"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
}

# 1 つの層 (home / private) を ~ へリンクする。
# PARTIAL_DIRS に該当する間は掘り下げ、そうでない要素をリンクする。
link_tree() {
  layer=$1
  rel=$2   # 層からの相対パス。トップレベルは空

  base="$DOTFILES_DIR/$layer${rel:+/$rel}"
  for child in $(ls -A "$base"); do
    path=${rel:+$rel/}$child
    if is_partial "$path"; then
      mkdir -p ~/"$path"
      link_tree "$layer" "$path"
    else
      link_into_home "$base/$child" ~/"$path"
    fi
  done
}

link_layer() {
  [ -d "$DOTFILES_DIR/$1" ] || return 0
  link_tree "$1" ''
}
