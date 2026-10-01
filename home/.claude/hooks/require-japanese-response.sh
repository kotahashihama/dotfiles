#!/bin/bash
#
# 応答の地の文が英語になったら、日本語で書き直させる Stop フック。
#
# 日本語で応答する規約は CLAUDE.md と出力スタイルの両方にあるが、長い会話の途中で
# 地の文が丸ごと英語になることがある。読めば気づける形ではなく、思い出せるのに破る形
# なので、文章を足しても止まらない（rule_conventions.md の「フックへ寄せる」）。
#
# 識別子・コード・コマンド・URL は英語のままが正しいので、コードブロック・インライン
# コード・URL を除いた残りで、仮名と漢字が英字に対してどれだけあるかを見る。
#
# **1プロンプトにつき1回しか止めない。** 目印は他の Stop フックと共有する。
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

# 英語のままが正しいものを除く
prose = re.sub(r"```.*?```", " ", msg, flags=re.S)          # コードブロック
prose = re.sub(r"`[^`\n]*`", " ", prose)                     # インラインコード
prose = re.sub(r"https?://\S+", " ", prose)                  # URL
prose = re.sub(r"\]\([^)]*\)", "]", prose)                   # Markdown のリンク先
# パス・JSON・識別子のように記号を含む語は地の文ではない
prose = re.sub(r"\S*[/\\_{}=<>\"\\[\]@#$|]\S*", " ", prose)

jp = len(re.findall(r"[぀-ヿ㐀-鿿ｦ-ﾟ]", prose))
latin = len(re.findall(r"[A-Za-z]", prose))

# 短い応答（「OK」やリンクだけ）と、地の文がほとんど無い応答は見ない
if latin < 200:
    raise SystemExit(0)
# 日本語の地の文なら仮名と漢字が英字を大きく上回る。固有名詞や識別子が混ざっても
# 2割を切ることはまず無い
if jp >= (jp + latin) * 0.2:
    raise SystemExit(0)

# 同じプロンプトで二度は止めない（鍵は Stop フック共通）
mark = os.path.join(tempfile.gettempdir(), "claude-stopguard-" + pid)
if os.path.exists(mark):
    raise SystemExit(0)
open(mark, "w").close()

sys.stderr.write(
    "**応答の地の文が英語になっています。日本語で書き直してください**"
    "（CLAUDE.md の「ユーザーについて」）。\n\n"
    "識別子・コード・コマンド・URL・固有名詞は原語のままでよく、"
    "それ以外の文を日本語にします。内容は変えず、同じ報告を日本語で出し直してください。"
)
raise SystemExit(2)
PY
