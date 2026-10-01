#!/bin/bash
#
# 意味のない停止を止める Stop フック。
#
# 「よければ着手します」で終える形は、答えが分かっているのに委ねているだけで、
# ユーザーは「続けて」と言うために呼ばれることになる（decide_or_ask.md）。
#
# **1プロンプトにつき1回しか止めない。** 誤検知しても1ターン余計に進むだけで、
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

# 「次にこれをやります」と宣言して終える形。Stop が発火した時点で止まって
# いるので、宣言があること自体が違反にあたる。tool_use を見る必要は無い。
# 5回宣言して5回とも止まった実測がある
DECL = re.compile(r"(続けて|次に|次は|この後|続いて)[^。\n]{0,30}"
                  r"(呼びます|実行します|進めます|流します|やります|直します|"
                  r"確認します|見ます|作ります|足します|測ります)")

# 取り消せない操作は、宣言して止まるのが正しい（decide_or_ask.md /
# no_auto_ready_pr.md / responding_to_reviews.md）
WAIT_OK = re.compile(r"(push|マージ|merge|ready|コミット|commit|返信|投稿|"
                     r"再依頼|force|Resolve)")

# 「次に触るときに」のような先送りの表明は、いま実行するものではない
LATER = re.compile(r"(次|今度|後)に(触る|触れる|来る|見る|書く|直す)とき")

declared = (bool(DECL.search(msg)) and not WAIT_OK.search(msg)
            and not LATER.search(msg))

# 判断を本文で求めたまま、AskUserQuestion を使わずに終える形。
# 規約は「選択肢が2つ以上あれば必ずツールで」と定めているが、拒否で止まった
# ときの報告や状況への答えの中で、本文に案を並べて終える形が繰り返し出た。
# 直近14日の実測で、この言い回しで終えた応答のうち、ツールを伴わないものが27件、
# 伴うものが15件。27件のうち誤検知（操作の手順を伝えているだけ）は約3件だった
ASK = re.compile(r"(ご判断ください|判断をお願いします|どうしますか|どれにしますか|"
                 r"どちらにしますか|どれにするか|どちらにするか|決めてください|"
                 r"決めていただ|選んでください)")


def asked_with_tool(path):
    """最後の人の入力より後に AskUserQuestion を呼んでいれば真。読めなければ真（止めない）"""
    try:
        entries = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
    except (OSError, ValueError):
        return True
    asked = False
    for e in entries:
        if e.get("type") == "user" and (e.get("origin") or {}).get("kind") == "human":
            asked = False
        elif e.get("type") == "assistant":
            for c in e.get("message", {}).get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "AskUserQuestion":
                    asked = True
    return asked


unasked = bool(ASK.search(msg)) and not asked_with_tool(str(d.get("transcript_path", "")))
if not (declared or unasked or any(re.search(p, msg) for p in PATTERNS)):
    raise SystemExit(0)

# 同じプロンプトで二度は止めない
# 鍵は Stop フック共通。別々に持つと、同じターンで2本とも止めて
# 差し戻しが2回になる。見送った側は次のターンで拾う
mark = os.path.join(tempfile.gettempdir(), "claude-stopguard-" + pid)
if os.path.exists(mark):
    raise SystemExit(0)
open(mark, "w").close()

if unasked:
    sys.stderr.write(
        "**本文で判断を求めたまま、AskUserQuestion を使わずに終えています**"
        f"（「{ASK.search(msg).group(0)}」）。\n\n"
        "選択肢が2つ以上ある・可否を尋ねるなら、本文には背景と根拠だけを残し、"
        "案は AskUserQuestion の選択肢として出し直してください。推奨を先頭に置き、"
        "label に「（推奨）」を付けます（decide_or_ask.md「尋ねるときの形」）。\n\n"
        "判断を求めておらず、操作の手順を伝えているだけなら、その旨を1行で述べて終えてください。"
    )
    raise SystemExit(2)

sys.stderr.write(
    "**やることが決まっているなら、着手の許可を求めずに進めてください**"
    "（decide_or_ask.md）。\n\n"
    "「よければ〜します」と書けるのは、よくない理由が思い当たらないからです。"
    "つまり答えは分かっています。分かっているなら、やる。\n\n"
    "**「次に〜します」と書いたなら、そのまま実行してください。** 宣言だけ残すと、"
    "ユーザーは promise を受け取ることになります。区切りの報告は進みながら出す。\n\n"
    "本当にユーザーの判断が要るなら、地の文ではなく AskUserQuestion で"
    "選択肢を出してください（decide_or_ask.md）。取り消せない操作"
    "（コミット・push・ready 化）はそのまま止まって構いません。"
)
raise SystemExit(2)
PY
