"""会話・投稿・書いたファイルから、開けなくなる URL を拾う

require-japanese-response.sh・lint-github-body.sh・require-review-before-post.sh・check-writing-in-files.sh から呼ぶ。

拾うもの:
- URL の直後に続けた括弧と句読点。ターミナルは空白か行末までを1つの URL と見るので、
  続けた文字まで URL に入り、リンクが壊れる（ report_formatting.md の「URL: 直後に括弧書きや句読点を続けない」）
見ないもの:
- コードブロックとインラインコードの中、「」の中（規約を引いて話すとき）
- Markdown のリンクの URL（ [文字](URL) の括弧は記法の一部）

定型の締めと pnpm run も一度ここで拾っていたが、外した（2026-11-19）。フックにするのは、
取り消せない操作か、苛立ちの大きい失敗だけにするとユーザーが決めた。どちらも後から直せる
"""
import re

URL_THEN_PUNCT = re.compile(r"(?<!\]\()https?://[^\s）)\]>]+?[（(。、）]")


def strip_quoted(text):
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    text = re.sub(r"`[^`\n]*`", " ", text)
    return re.sub(r"「[^」\n]*」", " ", text)


def check_report(text):
    """書式の崩れを、(種類, 文字) の組で見つけた順に返す"""
    body = strip_quoted(text)
    found = [("URL の直後の括弧・句読点", m.group(0)[-40:]) for m in URL_THEN_PUNCT.finditer(body)]
    return found
