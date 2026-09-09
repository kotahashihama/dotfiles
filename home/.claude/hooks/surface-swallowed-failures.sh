#!/bin/bash
#
# 出力を読まないと気づけない形を拾う PostToolUse フック。2つ見る。
#
#   1. ツールは成功したが、中のコマンドが失敗していた
#   2. 集計を head / tail で切っており、枠ちょうどで返ってきた
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

# 実測した形は `tool_response` で、`stdout` / `stderr` を持つ。
# ドキュメントは `tool_result` と書いているが、その名では常に空になる。
res = d.get("tool_response", d.get("tool_result", ""))
if isinstance(res, dict):
    r = "\n".join(str(res.get(k, "")) for k in ("stdout", "stderr"))
elif isinstance(res, list):
    r = "\n".join(map(str, res))
else:
    r = str(res)
if not r.strip():
    sys.exit(0)

# 誤検知しにくいものだけ。「error」のような一般語は入れない
#（grep の対象文字列や、正常な出力に普通に現れる）
SIGNS = [
    (r"^fatal: ",                       "git が fatal で終了している"),
    (r"^error: (?:failed|cannot|unable)", "git が error で終了している"),
    (r"cannot overwrite existing file",  "noclobber がリダイレクトを拒んだ（ `>|` を使う）"),
    (r"^[^\n]*: command not found",      "コマンドが見つかっていない"),
    (r"^[^\n]*: Permission denied",      "権限で拒否されている"),
    (r"^Traceback \(most recent call",   "Python が例外で終了している"),
    (r"^\s*Aborting$",                   "処理が中断されている"),
]

found = []
for pat, why in SIGNS:
    if re.search(pat, r, re.M):
        found.append(why)

parts = []
if found:
    parts.append(
        "このコマンドは成功として返っていますが、出力に失敗の兆候があります: "
        + " / ".join(found)
        + "。パイプラインの終了ステータスは最後のコマンドのものになり、`;` で繋いだ前段の"
          "失敗も残りません。**この結果を根拠に次へ進む前に、意図した処理が実際に走ったかを"
          "確かめてください**（verify_before_asserting.md）"
    )

# 集計を切っている形だけを見る。切ること自体は Bash 呼び出しの49%で
# やっており（実測 27,079/55,214）、全部に出すと読まれなくなる。
# 集計の後で切っていて、かつ枠に達したものは1日あたり約2.2回（実測 265件/4か月）。
#
# **塞げるのは一部だけ。** `| head` だけ打って次のターンで数える形は、
# 切る行為と数える行為が別のターンなので、コマンドを見ても繋げられない。
# それが27,079件の大半にあたる（verify_the_check_worked.md の
# 「集計を、自分で切った出力から読まない」）。
cmd = (d.get("tool_input") or {}).get("command", "")
AGG = r"(?:uniq\s+-c|wc\s+-l|sort\b[^|]*)"
CUT = r"\|\s*(head|tail)\s+-(?:n\s*)?(\d+)\b"
m = re.search(AGG + r"[^|]*" + CUT, cmd)
if m:
    n = int(m.group(2))
    lines = len([l for l in r.split("\n") if l.strip()])
    # head -N は N 行までしか出さないので、N 行ちょうどなら枠に達している。
    # 元が N 行ちょうどだった場合は誤検知になるが、区別が付かないので
    # 「切れている」ではなく「切れている可能性」と書く。
    if lines >= n:
        parts.append(
            "この出力は `%s -%d` の枠ちょうど（%d行）で、**切れている可能性があります**。"
            "集計を切っているので、**件数や有無の根拠にするなら切らずに数え直してください**。"
            "切った時点では何も主張していないぶん、後のターンでは普通の一覧に見えます"
            "（verify_the_check_worked.md）" % (m.group(1), n, lines)
        )

if not parts:
    sys.exit(0)

msg = "\n".join(parts)
# additionalContext は Claude へ、systemMessage はユーザーの表示へ届く。
# 確かめ直すのは Claude なので、両方に出す。
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": msg,
    },
    "systemMessage": msg,
}, ensure_ascii=False))
PY
exit 0
