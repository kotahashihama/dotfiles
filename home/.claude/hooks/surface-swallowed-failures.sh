#!/bin/bash
#
# Bash ツールは成功したが、中のコマンドが失敗していた形を拾う PostToolUse フック。
#
# パイプラインの終了ステータスは最後のコマンドのものになり、`;` で繋いだ
# 前段の失敗も残らない。どちらもツール自体は成功として返るので、出力を
# 読まない限り失敗に気づけない（verify_before_asserting.md）。
#
# 止めることはできない（実行済み）。気づかせるだけ。
#
set -u

payload=$(cat)

python3 - "$payload" <<'PY'
import json, re, sys

try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

r = d.get("tool_result", "")
if isinstance(r, dict):
    r = " ".join(str(v) for v in r.values())
elif isinstance(r, list):
    r = " ".join(map(str, r))
r = str(r)
if not r:
    sys.exit(0)

# 誤検知しにくいものだけ。「error」のような一般語は入れない
#（grep の対象文字列や、正常な出力に普通に現れる）
SIGNS = [
    (r"^fatal: ",                       "git が fatal で終了している"),
    (r"^error: (?:failed|cannot|unable)", "git が error で終了している"),
    (r"cannot overwrite existing file",  "noclobber がリダイレクトを拒んだ（`>|` を使う）"),
    (r"^[^\n]*: command not found",      "コマンドが見つかっていない"),
    (r"^[^\n]*: Permission denied",      "権限で拒否されている"),
    (r"^Traceback \(most recent call",   "Python が例外で終了している"),
    (r"^\s*Aborting$",                   "処理が中断されている"),
]

found = []
for pat, why in SIGNS:
    if re.search(pat, r, re.M):
        found.append(why)

if not found:
    sys.exit(0)

msg = (
    "このコマンドは成功として返っていますが、出力に失敗の兆候があります: "
    + " / ".join(found)
    + "。パイプラインの終了ステータスは最後のコマンドのものになり、`;` で繋いだ前段の"
      "失敗も残りません。**この結果を根拠に次へ進む前に、意図した処理が実際に走ったかを"
      "確かめてください**（verify_before_asserting.md）"
)
print(json.dumps({"systemMessage": msg}, ensure_ascii=False))
PY
exit 0
