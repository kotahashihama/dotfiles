#!/bin/bash
#
# ユーザーの訂正・好みの表明を検知して、資産化の検討を促す UserPromptSubmit フック。
#
# 何をルール化するかはここに書かない。促すだけで、判断は learn-rules スキルと
# ask_before_editing_claude_assets.md が持つ。両方に書くと片方だけ古くなる。
#
set -u

payload=$(cat)

# プロンプトの格納キーは公式ドキュメントに明記が無い。候補すべてを繋いで見る。
# 先勝ちで 1 つに絞ると、別のキーに入っていたときに静かに機能しなくなる。
text=$(printf '%s' "$payload" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
keys = ("prompt", "user_prompt", "user_prompt_raw")
print("\n".join(str(d[k]) for k in keys if isinstance(d.get(k), str) and d[k]))
' 2>/dev/null) || exit 0

[ -n "$text" ] || exit 0

# 拾うのは「言い直された」「毎回そうしている」「理由つきで求められた」の 3 系統。
# 依頼そのもの（「〜して」）は拾わない。それは日常の指示で、繰り返しの兆候ではない。
matched=$(printf '%s' "$text" | python3 -c '
import re, sys
t = sys.stdin.read()

patterns = (
    # 訂正・打ち消し。直前の振る舞いを否定している
    r"そうじゃなく|そうではなく|じゃなくて|ではなく[、。]|違[うっ]|やめて|ダメ|駄目|不要だ|(?:要|い)ら(?:ない|ん)",
    # 頻度。1 回きりではないことを示す
    r"毎回|いつも|常に|また[（(]?同じ|何度も|今後は|以降は|次から",
    # 恒久化の要求
    r"ルール化|規約化|資産化|覚えてお|記憶して|設定して(?:おいて|ね)",
    # 理由つきの好み。「〜だから〜して」の形
    r"だから.{0,20}(?:して|でお願い|にして)|ので.{0,20}(?:して|でお願い|にして)",
    # 基本方針の宣言
    r"基本方針|原則として|方針として",
)
hits = [p for p in patterns if re.search(p, t)]
print(len(hits))
' 2>/dev/null) || exit 0

[ "${matched:-0}" -gt 0 ] || exit 0

python3 -c '
import json
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": (
        "このプロンプトは訂正・好みの表明・恒久化の要求を含む可能性があります。"
        "対応を終えたら、それが 1 回きりの指示ではなく繰り返し効く規約かを判定し、"
        "該当するなら learn-rules スキルの手順に従ってください。"
        "既存の資産が実態と食い違っている場合も同スキルの対象です。"
        "1 回きりの指示なら何もしません。"
    ),
}}, ensure_ascii=False))'
