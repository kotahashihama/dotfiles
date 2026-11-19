#!/bin/bash
#
# Stop フックの入口。応答を見る検査を順に走らせ、見つけた違反をまとめて1回で返す。
#
# 検査は4本ある。
#   require-japanese-response.sh  応答の言語・表記・参照のリンク
#   block-pointless-stop.sh       意味のない停止（許可待ち・宣言だけ・本文での問い）
#   check-writing-in-files.sh     このターンに書いた Markdown の表記
#   require-writing-review.sh     このターンに書いた Markdown を点検に通したか
#
# 4本を別々に登録していたときは、目印のファイルを共有して「最初に止めた1本だけが
# 言い、残りは黙る」形になっていた。同じターンの別の違反が素通りし、数え方も
# 1回きりの3本と3回までの1本で食い違っていた。入口を1本にして、全部を見てから
# まとめて返し、止める回数もここだけで数える。
#
# 上限は1プロンプトにつき3回。1回だけにしていたときは、差し戻し後の応答の22%
# （59回中13回）がまだ違反していた。外すと、直せない違反で往復が終わらない。
#
set -u

payload=$(cat)
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pid=$(printf '%s' "$payload" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("prompt_id",""))
except Exception: print("")')
[ -n "$pid" ] || exit 0

mark="${TMPDIR:-/tmp}/claude-stopguard-$pid"
done_count=$(cat "$mark" 2>/dev/null || echo 0)
[ "${done_count:-0}" -ge 3 ] 2>/dev/null && exit 0

out=""
for check in require-japanese-response.sh block-pointless-stop.sh check-writing-in-files.sh require-writing-review.sh; do
  msg=$(printf '%s' "$payload" | bash "$dir/$check" 2>&1 >/dev/null)
  if [ $? -eq 2 ] && [ -n "$msg" ]; then
    out="${out:+$out

---

}$msg"
  fi
done

[ -n "$out" ] || exit 0
echo $(( ${done_count:-0} + 1 )) >| "$mark"
printf '%s\n' "$out" >&2
exit 2
