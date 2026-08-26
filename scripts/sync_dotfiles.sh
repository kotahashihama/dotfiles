#!/bin/sh
#
# 環境の変化をリポジトリへ取り込み、状態を点検する。
#
# 日常的に走らせるのはこれ1本。コミットと push はしない。
# 何を残すかはユーザーが決める（rules/no_auto_commit.md）。
#
set -eu

. "$(dirname "$0")/lib.sh"

cd "$DOTFILES_DIR"

echo "── Brewfile を実態へ ──"
before=$(grep -cE '^(brew|cask|tap|vscode|mas) ' Brewfile 2>/dev/null || echo 0)
brew bundle dump --force --file=Brewfile
after=$(grep -cE '^(brew|cask|tap|vscode|mas) ' Brewfile)
echo "   宣言 $before → ${after}件"

# dump は tap 由来の formula を落とすことがある。実体があるのに消えた分を戻す
echo "── 落ちた宣言を戻す ──"
# パイプの while はサブシェルで走るため、件数は一時ファイルで受ける
_missing=$(mktemp)
brew list --formula --full-name 2>/dev/null | grep '/' > "$_missing.all" || true
: > "$_missing"
while read -r f; do
  grep -q "\"$f\"" Brewfile || printf '%s\n' "$f" >> "$_missing"
done < "$_missing.all"
if [ -s "$_missing" ]; then
  while read -r f; do
    printf 'brew "%s"\n' "$f" >> Brewfile
    echo "   戻した: $f"
  done < "$_missing"
else
  echo "   なし"
fi
rm -f "$_missing" "$_missing.all"

echo "── mise の一覧を書き出す ──"
mise ls --current > private/.inventory/mise.txt 2>/dev/null && echo "   $(grep -c '' private/.inventory/mise.txt)行" || echo "   mise が無い"

echo "── 宣言と実体の一致 ──"
brew bundle check --file=Brewfile --no-upgrade 2>&1 | tail -1 | sed 's/^/   /'

echo "── リンク切れ ──"
n=$(find "$HOME" -maxdepth 3 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
echo "   ${n}件"

echo "── 未コミットの変更 ──"
git status --short | sed 's/^/   /' || true
echo
echo "変更を確認したらコミットし、./scripts/backup_dotfiles.sh でアーカイブを作る。"
