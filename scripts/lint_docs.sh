#!/bin/bash
#
# グローバル資産の表記を検査する。
#
# フックは編集した1ファイルの、しかも新しく出た指摘だけを返す。溜まった
# ぶんは誰も見に行かないので、全体を見るときはこちらを使う。
#
# 文体と AI っぽさは機械では測らない。パターン照合と統計で見る道具は、
# 番号付き手順と短い宣言文でできたこの資産群を house style ごと叩いた
# （194件のうち167件）。読ませる相手は /agy-review。
#
# 使い方:
#   ./scripts/lint_docs.sh              全体の内訳を出す
#   ./scripts/lint_docs.sh <ファイル>…  対象を絞る
#   ./scripts/lint_docs.sh --detail     1件ずつ該当行つきで出す
#
set -u

cd "$(dirname "$0")/.." || exit 1
HOOKS=home/.claude/hooks

detail=0
files=()
for a in "$@"; do
  case "$a" in
    --detail) detail=1 ;;
    *) files+=("$a") ;;
  esac
done
if [ ${#files[@]} -eq 0 ]; then
  files=(home/.claude/rules/*.md home/.claude/skills/*/SKILL.md
         home/.claude/CLAUDE.md home/.claude/agents/*.md)
  # 取り込んだ外部の文書は原文のまま置くので、こちらの表記規約を当てない。
  # 1件でも残ると「0件」を基準に使えなくなる
  keep=()
  for f in "${files[@]}"; do
    case "$f" in */japanese-tech-writing/*) ;; *) keep+=("$f") ;; esac
  done
  files=("${keep[@]}")
fi

echo "対象: ${#files[@]}ファイル"

python3 "$HOOKS/check-japanese-spacing.py" "${files[@]}" >| /tmp/lint_docs_spacing.$$ 2>/dev/null
n=$(wc -l < /tmp/lint_docs_spacing.$$ | tr -d ' ')
echo ""
echo "== 表記: ${n}件 =="
if [ "$n" != 0 ]; then
  # uniq は使わない。macOS の uniq は日本語を含む相異なる行を同一として畳み、
  # 4カテゴリ11件が1カテゴリ11件として出た（verify_the_check_worked.md）
  cut -f2 /tmp/lint_docs_spacing.$$ | python3 -c '
import collections, sys
for k, v in sorted(collections.Counter(sys.stdin.read().splitlines()).items(),
                   key=lambda kv: (-kv[1], kv[0])):
    print("   %-32s %4d" % (k, v))'
  [ "$detail" = 1 ] && sed 's|^|   |' /tmp/lint_docs_spacing.$$
fi
rm -f /tmp/lint_docs_spacing.$$
