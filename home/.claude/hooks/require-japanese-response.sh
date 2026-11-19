#!/bin/bash
#
# 応答の地の文が日本語以外（英語・中国語・韓国語など）になったら、日本語で書き直させる Stop フック。
# 日本語の応答なら、表記（数値と単位・約物・インラインコードの前後・英単語の境目）も
# check-japanese-spacing.py で見る。応答を集める手順が同じなので、1本にまとめている。
#
# 応答の言語は settings.json の language で日本語にしているが、長い会話の途中で
# 地の文が丸ごと英語や中国語になることがある。指示の文を足しても止まらないので、
# 書き直させる側をフックが持つ（rule_conventions.md の「フックへ寄せる」）。
#
# 識別子・コード・コマンド・URL は英語のままが正しいので、コードブロック・インライン
# コード・URL を除いた残りで、文字のうち仮名がどれだけあるかを見る。漢字は数えない。
# 漢字を日本語の文字に数えると、中国語の応答が日本語として通るため。
#
# **最後の応答だけでなく、ツール呼び出しの合間に書いた途中経過の文も見る。** 途中経過は
# 1つずつが短く、最後の応答だけを見ると日本語以外のまま素通りする。実際に、途中経過が英語の
# ままツールを呼び続け、ユーザーに「日本語で話して」と2回言われた。文の塊ごとに英語が
# 主かを判定し、日本語以外の塊の文字数を足して見る（まとめて割合を出すと、最後の長い日本語の
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
    kana = len(re.findall(r"[ぁ-ゟァ-ヿｦ-ﾟ]", prose))
    letters = sum(ch.isalpha() for ch in prose)
    return kana, letters


def foreign(kana, letters):
    # 日本語の地の文なら、文字（仮名・漢字・英字ほか）のうち仮名が2割を超える。
    # 2026-11-19 に直近60本の会話ログの日本語の応答で測ると、最小が23.4%だった。
    # 中国語・韓国語・英語では仮名がほぼ出ないので、1割で切る
    return kana < letters * 0.1


blocks = turn_texts(transcript, pid) if transcript else []
if msg and (not blocks or blocks[-1].strip() != msg.strip()):
    blocks.append(msg)

# 最後の応答は従来どおり単独で見る（短い応答とリンクだけの応答は見ない）
kana, letters = counts(msg)
final_foreign = letters >= 200 and foreign(kana, letters)

# 途中経過は、日本語以外が主の塊（文字40字以上）の文字数を足して見る
mid_letters = 0
for b in blocks:
    bk, bl = counts(b)
    if bl >= 40 and foreign(bk, bl):
        mid_letters += bl
mid_foreign = mid_letters >= 200

# 日本語の応答なら、表記も見る（数値と単位・約物・インラインコードの前後・英単語の境目）。
# ファイルと GitHub への投稿には別のフックが掛かるが、会話への応答には掛かっていなかった。
# 判定は check-japanese-spacing.py に1か所で持たせ、ここでは呼ぶだけにする
spacing = []
# PR・issue・課題の参照がクリックで開ける形かも見る（ report_formatting.md ）。
# 判定は check-reference-links.py が持つ。目印を共有するので、表記と同じ回に並べて返す
links = []
if not (final_foreign or mid_foreign):
    import importlib.util

    def load(name, path):
        spec = importlib.util.spec_from_file_location(name, os.path.expanduser(path))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

    try:
        mod = load("spacing", "~/.claude/hooks/check-japanese-spacing.py")
        for b in blocks:
            spacing += [(cat, text) for _, cat, text in mod.check_text(b)]
    except Exception:
        spacing = []
    try:
        ref = load("links", "~/.claude/hooks/check-reference-links.py")
        for b in blocks:
            for item in ref.check_links(b):
                if item not in links:
                    links.append(item)
    except Exception:
        links = []
    if not spacing and not links:
        raise SystemExit(0)

# 同じプロンプトで二度は止めない（鍵は Stop フック共通）
mark = os.path.join(tempfile.gettempdir(), "claude-stopguard-" + pid)
if os.path.exists(mark):
    raise SystemExit(0)
open(mark, "w").close()

if spacing or links:
    parts = []
    if spacing:
        shown = "\n".join(f"- {cat}: {text[:60]}" for cat, text in spacing[:8])
        more = f"\nほか {len(spacing) - 8} 件" if len(spacing) > 8 else ""
        parts.append(
            "**応答の表記が規約から外れています**（ `no_space_between_number_and_unit.md` ）。\n\n"
            f"{shown}{more}\n\n"
            "数値と単位は詰め、独立した英単語と日本語のあいだ・インラインコードの前後は空けます。"
        )
    if links:
        shown = "\n".join(f"- {cat}: {text}" for cat, text in links[:8])
        more = f"\nほか {len(links) - 8} 件" if len(links) > 8 else ""
        parts.append(
            "**PR・issue・課題の参照がクリックで開けない形です**（ `report_formatting.md` ）。\n\n"
            f"{shown}{more}\n\n"
            "見せる文字は URL・owner/repo#番号・課題キーのどれでもよく、どれもリンクにします"
            "（PR は owner/repo#番号 か [文字](URL)、課題は [キー](URL)）。"
        )
    sys.stderr.write(
        "\n\n".join(parts)
        + "\n\n該当する文だけを直して、直した文を出し直してください（応答全体を繰り返さなくてよい）。"
    )
    raise SystemExit(2)

where = "応答の地の文" if final_foreign else "ツール呼び出しの合間に書いた途中経過の文"
sys.stderr.write(
    f"**{where}が日本語以外の言語になっています。日本語で書き直してください**"
    "（ `settings.json` の `language` ）。\n\n"
    "識別子・コード・コマンド・URL・固有名詞は原語のままでよく、"
    "それ以外の文を日本語にします。内容は変えず、同じ報告を日本語で出し直してください。"
    "途中経過も、この先は日本語で書きます。"
)
raise SystemExit(2)
PY
