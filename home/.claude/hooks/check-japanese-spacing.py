"""日本語の表記を検査する。

textlint も suiko も、数値と単位のあいだの空白や全角の約物の後ろの空白は
見ない。書く場所ごとに別々の実装を置くと judgement がずれるので、判定は
ここ1か所に置き、ファイル・GitHub への投稿・会話への応答から呼ぶ。

規約は no_space_between_number_and_unit.md と no_em_dash_in_japanese.md。

使い方:
    python3 check-japanese-spacing.py <ファイル>...
    → 違反を「パス:行番号\tカテゴリ\t該当行」で1件1行に出す
"""
import re
import sys

UNIT = (r'(?:万|億|千|百|つ|件|行|本|回|個|人|箇所|秒|分|時間|日|週|月|年|倍|割|'
        r'文字|字|語|種|通り|段|層|周|重|度|点|ファイル|ケース|パターン|コミット|'
        r'ページ|MB|GB|KB|TB|MiB|GiB|ms|%|vCPU|px)')
JA = r'[ぁ-んァ-ヶ一-龥々〜]'
YAKUMONO = r'[、。「」『』（）【】・？！]'
# インラインコードとの境界は、約物の形で分かれる。囲む約物は右側にグリフが
# 来るのでコードの背景と接し、句読点は右下にグリフがあって右側が空白になる
BRACKET = r'[「」『』（）【】]'
TIGHT = r'[、。・？！]'

# 直前が英字か記号なら識別子の一部（ `BE v2 と ` `Go 1.21 で ` `#3150 の ` ）。
# 「英単語 + 空白 + 数字」も名前の一部（ `TypeScript 7` `Go 8` ）。規約は
# 「英字 ↔ 日本語は空白を入れる」としているので、そちらは正しい形。
# ただしその英字の前が日本語ならラベルなので（ ` 案 A 3件 ` ）、除外から外す
NOT_ID_L = (r'(?<![A-Za-z0-9._#/=$-])'
            r'(?:(?<![A-Za-z] )|(?<=' + JA + r' [A-Za-z] ))')
NOT_ID_R = r'(?![0-9A-Za-z._/=-])'

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


def check_text(text, code=False):
    """違反を (行番号, カテゴリ, 該当行) で返す

    code=True はコードのファイル。コメントと文字列だけを見たいので、
    日本語を含む行に絞る。言語ごとにコメント記号を並べるより漏れが少ない。
    """
    hits = []
    lines = ((n, l) for n, l in enumerate(text.split('\n'), 1)
             if re.search(JA, l)) if code else prose(text)
    for n, line in lines:
        # インラインコードは対象外。空白で伏せると、直後の約物が
        # 「前に空白がある」と誤判定されるので1文字へ置き換える
        masked = re.sub(r'`[^`]*`', 'X', line)
        for name, pat in CHECKS:
            if pat.search(masked):
                hits.append((n, name, line.strip()))
        # 全角の約物の隣。半角スラッシュ（A / B）と表の区切りは対象外。
        # インラインコードの前後は空けるのが規約なので、そこも対象外
        t = re.sub(r'`[^`]*`', 'X', re.sub(r'\s*`', '`', re.sub(r'`\s*', '`', line)))
        # 強調の記号は落とさない。`。** 次 ` の空白は `**` と本文のあいだで、
        # 描画すると約物の隣にはならない
        t = re.sub(r'\s+/\s+', '/', t)
        t = re.sub(r'\s*\|\s*', '|', t)
        # 見るのは約物の「後ろ」だけ。前側はリスト記号や強調の閉じで空白が
        # 入るのが普通で、規約の例（ ` 「変更履歴」 hoge` `、 hoge` ）も後ろ側
        if re.search(YAKUMONO + r' ', t):
            hits.append((n, '全角約物の後ろ', line.strip()))
        # インラインコードの前後は空ける。ただし句読点の直前は詰めるので、
        # 後ろ側から `、` `。` は外す
        for mm in re.finditer(r'`[^`\n]+`', line):
            b = line[:mm.start()]
            a = line[mm.end():]
            # 該当箇所だけを切り出す。1行に複数のコードがあると、行の全文
            # だけではどこが該当したのか探すことになる
            near = b[-4:] + mm.group(0) + a[:4]
            # 仮名漢字と囲む約物のあいだは空ける
            if (re.search('(?:' + JA + '|' + BRACKET + ')$', b)
                    or re.match('(?:' + JA + '|' + BRACKET + ')', a)):
                hits.append((n, 'インラインコードの前後', near))
                break
            # 句読点と中黒のあいだは詰める
            if re.search(TIGHT + ' $', b) or re.match(' ' + TIGHT, a):
                hits.append((n, '句読点とコードのあいだ', near))
                break
        # 句読点の直前だけは前側も見る。`、` `。` の前に空白が入る形は
        # 無い。他の約物（ ` 「 ` ` （ ` ）はリスト記号や強調の閉じで空白が
        # 入るので、前側を見ると誤検知になる
        # 判定は masked 側。t はバッククォート周りの空白を潰しているので、
        # 句読点の直前の空白まで消えてしまう
        if re.search(r' [、。]', masked):
            hits.append((n, '句読点の直前', line.strip()))
    return hits


# Markdown 以外はコードとして扱う。コメントと文字列に日本語が出る
MARKDOWN = ('.md', '.markdown')


def check(path):
    text = open(path, encoding='utf-8').read()
    return check_text(text, code=not path.endswith(MARKDOWN))


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
