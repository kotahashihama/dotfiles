#!/bin/bash
#
# AskUserQuestion の選択肢に推奨が示されているかを検査する PreToolUse フック。
#
# decide_or_ask.md は「推す案を先頭に置き、label に（推奨）を付ける」と
# 規定しているが、文章だけでは実行時に効かない。形だけで判定できるので
# フックへ寄せる（rule_conventions.md の「文章を直しても止まらないなら、フックへ寄せる」）。
#
# 判定は label への「推奨」の有無1点だけ。どれを推すかは判断が要るが、
# 示したかどうかは文字列で決まる。

payload=$(cat)

python3 - "$payload" <<'PY'
import json
import sys

try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

questions = data.get("tool_input", {}).get("questions") or []
if not questions:
    sys.exit(0)

bad = []
for q in questions:
    labels = [str(o.get("label", "")) for o in (q.get("options") or [])]
    if not labels:
        continue
    if not any("推奨" in l for l in labels):
        bad.append((q.get("header") or q.get("question", ""))[:28])

if not bad:
    sys.exit(0)

reason = ("選択肢に推奨が示されていません。付けてから尋ねてください。\n\n"
          + "\n".join("- 「%s」の選択肢の label に「推奨」がありません" % h for h in bad)
          + "\n\n推す案を先頭へ置き、label の末尾へ「（推奨）」を付ける。"
          + "\n推奨を出さないと、判断コストをユーザーへ全部渡すことになる。"
          + "\n  → decide_or_ask.md")
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": reason,
}}, ensure_ascii=False))
PY
