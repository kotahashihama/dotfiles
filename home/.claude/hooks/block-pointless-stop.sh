#!/bin/bash
#
# 意味のない停止を止める Stop フック。
#
# 「よければ着手します」で終える形は、答えが分かっているのに委ねているだけで、
# ユーザーは「続けて」と言うために呼ばれることになる（no_unnecessary_pausing.md）。
#
# **1 プロンプトにつき 1 回しか止めない。** 誤検知しても 1 ターン余計に進むだけで、
# 会話が止まらなくなることはない。
#
set -u

payload=$(cat)

python3 - "$payload" <<'PY'
import json, os, re, sys, tempfile

try:
    d = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)

msg = str(d.get("last_assistant_message", ""))
pid = str(d.get("prompt_id", ""))
if not msg or not pid:
    raise SystemExit(0)

# 「答えは分かっているのに委ねている」形だけを拾う。
# 判断が要る問いは AskUserQuestion へ出るので、ここには現れない。
PATTERNS = [
    r"よければ",
    r"進めてよろしい",
    r"着手してよろしい",
    r"(ご)?指示をお待ち",
    r"まだ(着手|実施|対応)していません",
    r"次のステップに進みますか",
    r"このまま進めますか",
]
if not any(re.search(p, msg) for p in PATTERNS):
    raise SystemExit(0)

# 同じプロンプトで二度は止めない
mark = os.path.join(tempfile.gettempdir(), "claude-stopguard-" + pid)
if os.path.exists(mark):
    raise SystemExit(0)
open(mark, "w").close()

sys.stderr.write(
    "**やることが決まっているなら、着手の許可を求めずに進めてください**"
    "（no_unnecessary_pausing.md）。\n\n"
    "「よければ〜します」と書けるのは、よくない理由が思い当たらないから——"
    "つまり答えは分かっています。分かっているなら、やる。\n\n"
    "本当にユーザーの判断が要るなら、地の文ではなく AskUserQuestion で"
    "選択肢を出してください（decide_or_ask.md）。取り消せない操作"
    "（コミット・push・ready 化）はそのまま止まって構いません。"
)
raise SystemExit(2)
PY
