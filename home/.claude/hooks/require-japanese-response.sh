#!/bin/bash
#
# 応答の地の文が英語になったら、日本語で書き直させる Stop フック。
#
# 日本語で応答する規約は AGENTS.md と出力スタイルの両方にあるが、長い会話の途中で
# 地の文が丸ごと英語になることがある。読めば気づける形ではなく、思い出せるのに破る形
# なので、文章を足しても止まらない（rule_conventions.md の「フックへ寄せる」）。
#
# 識別子・コード・コマンド・URL は英語のままが正しいので、コードブロック・インライン
# コード・URL を除いた残りで、仮名と漢字が英字に対してどれだけあるかを見る。
#
# **最後の応答だけでなく、ツール呼び出しの合間に書いた途中経過の文も見る。** 途中経過は
# 1つずつが短く、最後の応答だけを見ると英語のまま素通りする。実際に、途中経過が英語の
# ままツールを呼び続け、ユーザーに「日本語で話して」と2回言われた。文の塊ごとに英語が
# 主かを判定し、英語の塊の英字を足して見る（まとめて割合を出すと、最後の長い日本語の
# 応答に薄められる）。
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
transcript = str(d.get("transcript_path", ""))
if not pid:
    raise SystemExit(0)


def turn_texts(path, prompt_id):
    """このプロンプトで書いた地の文の塊を、会話ログから順に集める"""
    texts, started = [], False
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    e = json.loads(line)
                except Exception:
                    continue
                if not started:
                    started = e.get("type") == "user" and e.get("promptId") == prompt_id
                    continue
                # 次のプロンプトに入ったら打ち切る
                if e.get("type") == "user" and e.get("promptId") not in (None, prompt_id):
                    break
                if e.get("type") != "assistant":
                    continue
                content = (e.get("message") or {}).get("content")
                for c in content if isinstance(content, list) else []:
                    if isinstance(c, dict) and c.get("type") == "text" and c.get("text"):
                        texts.append(c["text"])
    except OSError:
        return []
    return texts


def counts(text):
    # 英語のままが正しいものを除く
    prose = re.sub(r"```.*?```", " ", text, flags=re.S)          # コードブロック
    prose = re.sub(r"`[^`\n]*`", " ", prose)                     # インラインコード
    prose = re.sub(r"https?://\S+", " ", prose)                  # URL
    prose = re.sub(r"\]\([^)]*\)", "]", prose)                   # Markdown のリンク先
    # パス・JSON・識別子のように記号を含む語は地の文ではない
    prose = re.sub(r"\S*[/\\_{}=<>\"\\[\]@#$|]\S*", " ", prose)
    jp = len(re.findall(r"[぀-ヿ㐀-鿿ｦ-ﾟ]", prose))
    latin = len(re.findall(r"[A-Za-z]", prose))
    return jp, latin


def english(jp, latin):
    # 日本語の地の文なら仮名と漢字が英字を大きく上回る。固有名詞や識別子が混ざっても
    # 2割を切ることはまず無い
    return jp < (jp + latin) * 0.2


blocks = turn_texts(transcript, pid) if transcript else []
if msg and (not blocks or blocks[-1].strip() != msg.strip()):
    blocks.append(msg)

# 最後の応答は従来どおり単独で見る（短い応答とリンクだけの応答は見ない）
jp, latin = counts(msg)
final_english = latin >= 200 and english(jp, latin)

# 途中経過は、英語が主の塊（英字40字以上）の英字を足して見る
mid_latin = 0
for b in blocks:
    bj, bl = counts(b)
    if bl >= 40 and english(bj, bl):
        mid_latin += bl
mid_english = mid_latin >= 200

if not (final_english or mid_english):
    raise SystemExit(0)

# 同じプロンプトで二度は止めない（鍵は Stop フック共通）
mark = os.path.join(tempfile.gettempdir(), "claude-stopguard-" + pid)
if os.path.exists(mark):
    raise SystemExit(0)
open(mark, "w").close()

where = "応答の地の文" if final_english else "ツール呼び出しの合間に書いた途中経過の文"
sys.stderr.write(
    f"**{where}が英語になっています。日本語で書き直してください**"
    "（AGENTS.md の「ユーザーについて」）。\n\n"
    "識別子・コード・コマンド・URL・固有名詞は原語のままでよく、"
    "それ以外の文を日本語にします。内容は変えず、同じ報告を日本語で出し直してください。"
    "途中経過も、この先は日本語で書きます。"
)
raise SystemExit(2)
PY
