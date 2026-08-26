"""日本語の表記を検査する。

textlint も suiko も、数値と単位のあいだの空白や全角の約物の後ろの空白は
見ない。書く場所ごとに別々の実装を置くと judgement がずれるので、判定は
ここ 1 か所に置き、ファイル・GitHub への投稿・会話への応答から呼ぶ。

規約は no_space_between_number_and_unit.md と no_em_dash_in_japanese.md。

使い方:
    python3 check-japanese-spacing.py <ファイル>...
    → 違反を「パス:行番号\tカテゴリ\t該当行」で 1 件 1 行に出す
"""
import re
import sys

UNIT = (r'(?:万|億|千|百|つ|件|行|本|回|個|人|箇所|秒|分|時間|日|週|月|年|倍|割|'
        r'文字|字|語|種|通り|段|層|周|重|度|点|ファイル|ケース|パターン|コミット|'
        r'ページ|MB|GB|KB|TB|MiB|GiB|ms|%|vCPU|px)')
JA = r'[ぁ-んァ-ヶ一-龥々〜]'
YAKUMONO = r'[、。「」『』（）【】・？！]'

# 英字に続く数字は識別子の一部（`BE v2 と` `Go 1.21 で` `#3150 の`）。
# 規約は「英字 ↔ 日本語は空白を入れる」としているので、そちらは正しい形。
# 前後の英数記号を除外しないと、識別子をまたいで拾ってしまう
# 直前が英字か記号なら識別子の一部（`v2` `1.21` `#3150`）。
# 「英単語 + 空白 + 数字」は名前の一部（`TypeScript 7` `Go 8`）。ただし
# その英字の前が日本語ならラベルなので（`案 A 3件`）、除外から外す
NOT_ID_L = (r'(?<![A-Za-z0-9._#/-])'
            r'(?:(?<![A-Za-z] )|(?<=' + JA + r' [A-Za-z] ))')
NOT_ID_R = r'(?![0-9A-Za-z._/-])'

CHECKS = [
    ('数値と単位', re.compile(NOT_ID_L + r'[0-9]+ ' + UNIT)),
    ('日本語と数字', re.compile(JA + r' [0-9]+' + NOT_ID_R)),
    ('数量と日本語', re.compile(NOT_ID_L + r'[0-9]+(?:' + UNIT + r')? ' + JA)),
    ('ダッシュ', re.compile('——')),
]


def prose(text):
    """コードブロック・引用・NG 例を除いた行を返す

    NG 例は規約に違反している形で正しい。直すと例が例でなくなる。
    """
    inblock = incomment = False
    for n, raw in enumerate(text.split('\n'), 1):
        line = raw.rstrip('\n')
        if line.lstrip().startswith('```'):
            inblock = not inblock
            continue
        opened, closed = '<!--' in line, '-->' in line
        skip = (inblock or incomment or opened
                or line.lstrip().startswith('>')
                or '❌' in line or '悪い例' in line)
        if opened and not closed:
            incomment = True
        if closed:
            incomment = False
        if skip:
            continue
        yield n, line


def check_text(text):
    """違反を (行番号, カテゴリ, 該当行) で返す"""
    hits = []
    for n, line in prose(text):
        # インラインコードは対象外。空白で伏せると、直後の約物が
        # 「前に空白がある」と誤判定されるので 1 文字へ置き換える
        masked = re.sub(r'`[^`]*`', 'X', line)
        for name, pat in CHECKS:
            if pat.search(masked):
                hits.append((n, name, line.strip()))
        # 全角の約物の隣。半角スラッシュ（A / B）と表の区切りは対象外
        t = re.sub(r'\s+/\s+', '/', masked)
        t = re.sub(r'\s*\|\s*', '|', t)
        # 見るのは約物の「後ろ」だけ。前側はリスト記号や強調の閉じで空白が
        # 入るのが普通で、規約の例（`「変更履歴」 hoge` `、 hoge`）も後ろ側
        if re.search(YAKUMONO + r' ', t):
            hits.append((n, '全角約物の後ろ', line.strip()))
    return hits


def check(path):
    return check_text(open(path, encoding='utf-8').read())


if __name__ == '__main__':
    total = 0
    for p in sys.argv[1:]:
        try:
            for n, name, line in check(p):
                print('%s:%d\t%s\t%s' % (p, n, name, line[:70]))
                total += 1
        except OSError:
            pass
    sys.exit(1 if total else 0)
