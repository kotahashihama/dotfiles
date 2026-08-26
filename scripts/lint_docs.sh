#!/bin/bash
#
# グローバル資産の文章を textlint と suiko に掛ける。
#
# フックは編集した1ファイルの、しかも新しく出た指摘だけを返す。溜まった
# ぶんは誰も見に行かないので、全体を見るときはこちらを使う。
#
# 使い方:
#   ./scripts/lint_docs.sh              全体の内訳を出す
#   ./scripts/lint_docs.sh <ファイル>…  対象を絞る
#   ./scripts/lint_docs.sh --detail     1件ずつ該当行つきで出す
#
set -u

cd "$(dirname "$0")/.." || exit 1
HOOKS=home/.claude/hooks
TEXTLINT="$HOOKS/textlint/node_modules/.bin/textlint"
SUIKO="$HOOKS/suiko/bin/suiko"

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
fi

echo "対象: ${#files[@]}ファイル"

if [ -x "$TEXTLINT" ]; then
  "$TEXTLINT" -c "$HOOKS/textlint/.textlintrc.json" -f json "${files[@]}" 2>/dev/null \
    | DETAIL=$detail python3 -c '
import json, os, sys, collections
r = json.load(sys.stdin)
c = collections.Counter(); per = collections.Counter(); rows = []
for f in r:
    lines = open(f["filePath"], encoding="utf-8").read().split("\n")
    for m in f["messages"]:
        rid = m["ruleId"].split("/")[-1]
        c[rid] += 1
        per[f["filePath"]] += 1
        src = (lines[m["line"]-1] if 0 < m["line"] <= len(lines) else "").strip()
        rows.append((f["filePath"], m["line"], rid, src))
print("\n== textlint: %d 件 / %d ファイル ==" % (sum(c.values()), len(per)))
for k, v in c.most_common():
    print("   %-32s %4d" % (k, v))
if os.environ.get("DETAIL") == "1":
    for p, ln, rid, src in sorted(rows):
        print("   %s:%d  %-26s %s" % (p.split("/")[-1], ln, rid, src[:64]))
'
else
  echo "  textlint 未導入（home/.claude/hooks/textlint で npm ci）"
fi

if [ -x "$SUIKO" ]; then
  # 相対パスは cwd を移す都合で解決できない。絶対パスへ直して渡す
  abs=()
  for f in "${files[@]}"; do
    case "$f" in /*) abs+=("$f") ;; *) abs+=("$PWD/$f") ;; esac
  done
  "$SUIKO" lint --genre tech --no-config --json "${abs[@]}" 2>/dev/null \
    | DETAIL=$detail python3 -c '
import json, os, sys, collections
d = json.load(sys.stdin)
if isinstance(d, dict):
    d = [d]
c = collections.Counter(); per = collections.Counter(); rows = []
for x in d:
    if not x["findings"]:
        continue
    per[x["file"]] += len(x["findings"])
    lines = open(x["file"], encoding="utf-8").read().split("\n")
    for f in x["findings"]:
        c[f["category"]] += 1
        src = (lines[f["line"]-1] if 0 < f["line"] <= len(lines) else "").strip()
        rows.append((x["file"], f["line"], f["category"], src))
print("\n== suiko: %d 件 / %d ファイル ==" % (sum(c.values()), len(per)))
for k, v in c.most_common():
    print("   %-32s %4d" % (k, v))
if os.environ.get("DETAIL") == "1":
    for p, ln, cat, src in sorted(rows):
        print("   %s:%d  %-26s %s" % (p.split("/")[-1], ln, cat, src[:64]))
'
else
  echo "  suiko 未導入（bash home/.claude/hooks/suiko/install.sh）"
fi

# 表記の検査。textlint も suiko も数値と単位の空白は見ない
python3 "$HOOKS/check-japanese-spacing.py" "${files[@]}" >| /tmp/lint_docs_spacing.$$ 2>/dev/null
n=$(wc -l < /tmp/lint_docs_spacing.$$ | tr -d ' ')
echo ""
echo "== 表記: ${n}件 =="
if [ "$n" != 0 ]; then
  cut -f2 /tmp/lint_docs_spacing.$$ | sort | uniq -c | awk '{printf "   %-32s %4d\n", $2, $1}'
  [ "$detail" = 1 ] && sed 's|^|   |' /tmp/lint_docs_spacing.$$
fi
rm -f /tmp/lint_docs_spacing.$$
