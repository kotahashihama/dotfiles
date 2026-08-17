#!/bin/sh
#
# 拡張子とアプリの関連付けを書き出す。
#
# macOS はこれを Launch Services のデータベースに持っており、defaults からは
# 触れない。新マシンでは「ダブルクリックしたら違うアプリが開く」が全部戻る。
#
set -e

. "$(dirname "$0")/lib.sh"

DEST="$DOTFILES_DIR/private/.associations"
EXTS='md markdown json ts tsx js jsx mjs cjs go rb py php tf tfvars sh zsh bash
yml yaml toml ini conf txt csv tsv log xml html css scss sql env gitignore
plist patch diff lock'

command -v duti >/dev/null 2>&1 || { echo "duti がありません。brew install duti してください" >&2; exit 1; }

mkdir -p "$DEST"
: > "$DEST/duti.txt"

n=0
for ext in $EXTS; do
  # duti -x は「アプリ名 / パス / バンドル ID」の 3 行を返す
  bundle=$(duti -x "$ext" 2>/dev/null | sed -n '3p')
  [ -n "$bundle" ] || continue
  printf '%s %s all\n' "$bundle" "$ext" >> "$DEST/duti.txt"
  n=$((n + 1))
done

echo "👍 関連付けを書き出しました: $n 件"
