"""会話への応答から、報告の書式の崩れを拾う

require-japanese-response.sh から呼ぶ。

拾うもの:
- URL の直後に続けた括弧と句読点。ターミナルは空白か行末までを1つの URL と見るので、
  続けた文字まで URL に入り、リンクが壊れる（ report_formatting.md の「URL: 直後に括弧書きや句読点を続けない」）
- 定型の締め（「答えは以上です」「他にあればお知らせください」）。no_ai_style_writing.md の「あちらが扱わない2つ」
見ないもの:
- コードブロックとインラインコードの中、「」の中（規約を引いて話すとき）
- Markdown のリンクの URL（ [文字](URL) の括弧は記法の一部）
- 「作業は以上です」。締めの1行で終わったことを知らせる形で、summarize_after_each_task.md が求めている
"""
import re

URL_THEN_PUNCT = re.compile(r"(?<!\]\()https?://[^\s）)\]>]+?[（(。、）]")
CLOSING = re.compile(
    r"(?m)(答え|報告|回答|説明|ご報告|共有)は以上(です|となります)"
    r"|^\s*以上(です|となります)。?\s*$"
    r"|他に(も)?(何か)?(気になる|ご不明|あれば).{0,10}(お知らせ|お申し付け|お気軽)"
)


def strip_quoted(text):
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    text = re.sub(r"`[^`\n]*`", " ", text)
    return re.sub(r"「[^」\n]*」", " ", text)


def check_report(text):
    """書式の崩れを、(種類, 文字) の組で見つけた順に返す"""
    body = strip_quoted(text)
    found = [("URL の直後の括弧・句読点", m.group(0)[-40:]) for m in URL_THEN_PUNCT.finditer(body)]
    found += [("定型の締め", m.group(0)) for m in CLOSING.finditer(body)]
    return found
