"""地の文が日本語かを判定する部品

Stop の require-japanese-response.sh と、PostToolUse の require-japanese-interim.py が使う。
判定を2か所に書くと、片方だけ直したときに見逃す文の幅が食い違うので、ここに1つだけ置く。
"""

import re


def counts(text):
    """英語のままが正しいもの（コード・URL・識別子）を除いた地の文の、仮名の数と文字の数を返す"""
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
    """日本語以外が主の地の文か

    日本語の地の文なら、文字（仮名・漢字・英字ほか）のうち仮名が2割を超える。
    2026-11-19 に直近60本の会話ログの日本語の応答で測ると、最小が23.4%だった。
    中国語・韓国語・英語では仮名がほぼ出ないので、1割で切る
    """
    return kana < letters * 0.1
