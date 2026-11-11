"""会話への応答から、クリックで開けない PR・issue・課題の参照を拾う

require-japanese-response.sh から呼ぶ。規定は report_formatting.md の
「PR・issue・課題に触れるときは、毎回クリックで開けるリンクにする」。

拾うもの:
- owner/repo の無い #番号（ #3596 ）。番号だけではターミナルでリンクにならない
- 裸の課題キー（ PROJ-123 ）。リンクにしないと開けない
見ないもの:
- コードブロックの中（コピーするための一覧）
- Markdown のリンク（ [文字](URL) ）の文字と URL、裸の URL、owner/repo#番号
- パスやブランチ名の一部（前が / か . 、後ろが -英字）
- 2桁以下の #番号。指摘の通し番号（ #2 ）と区別が付かない
- セッションの名前の中の課題キー（ PROJ-123 BE ・ PROJ-123 mypage FE ）。課題ではなくセッションを呼ぶ名前
"""
import re

# 課題キーの形をしているが、規格や方式の名前で課題ではないもの
NOT_ISSUE_PREFIXES = {"UTF", "ISO", "SHA", "AES", "RFC", "TLS", "HTTP", "CVE", "GPT", "ECMA", "IEEE", "JIS", "MD", "ES"}

# 後ろに BE・FE（間に小文字の語が1つ入ってもよい）が続くものは、セッションの名前として見ない
ISSUE_KEY = re.compile(
    r"(?<![\w/.\-#])([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*)-(\d+)(?![\w]|-[A-Za-z]|\s+(?:[a-z]+\s+)?(?:BE|FE)\b)"
)
BARE_NUMBER = re.compile(r"(?<![\w/&#])#(\d{3,})\b")


def strip_linked(text):
    """リンクになっているものとコードブロックを除く"""
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    text = re.sub(r"\[[^\]\n]*\]\([^)\s]*\)", " ", text)
    text = re.sub(r"https?://\S+", " ", text)
    text = re.sub(r"[\w.\-]+/[\w.\-]+#\d+", " ", text)
    return text


def check_links(text):
    """リンクにならない参照を、(種類, 文字) の組で見つけた順に返す"""
    body = strip_linked(text)
    found = [("owner の無い PR・issue の番号", m.group(0)) for m in BARE_NUMBER.finditer(body)]
    for m in ISSUE_KEY.finditer(body):
        if len(m.group(1)) < 2 or m.group(1) in NOT_ISSUE_PREFIXES:
            continue
        found.append(("リンクにしていない課題キー", m.group(0)))
    return found
