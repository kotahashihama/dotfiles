#!/bin/bash
#
# このターンに書いた Markdown の表記を検査する Stop フック。
#
# 書式の規約は「こちらが書くものすべて」が対象だが、フックが掛かるのは
# ファイルへの書き込みと GitHub への投稿だけだった。**書く量が最も多いのは
# 会話**で、そこに検査が無い（no_secret_values_in_output.md の「効くのは
# 形が決まっている経路だけ」と同じ穴）。
#
# ファイル側もここで見る。PostToolUse は「知らせる」だけで止められない
# （公式ドキュメント: PostToolUse cannot block; the tool already ran）ので、
# 書いた直後の指摘を無視できてしまう。Stop なら直すまで終われない。
#
# 止める回数の上限は入口の stop-checks.sh が持つ。
#
set -u

payload=$(cat)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOOK_DIR

python3 -I - "$payload" <<'PY'
import importlib.util
import io, json, os, re, subprocess, sys, tempfile

try:
    d = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)

pid = str(d.get("prompt_id", ""))
if not pid:
    raise SystemExit(0)

# 判定はファイル・GitHub 投稿と同じものを使う。書く場所ごとに実装を分けると
# 判定がずれる
path = os.path.join(os.environ["HOOK_DIR"], "check-japanese-spacing.py")
try:
    spec = importlib.util.spec_from_file_location("cjs", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
except Exception:
    raise SystemExit(0)

hits = []


# Bash で .md を書く形。読むだけのコマンド（cat・ls・grep）は拾わない。
# require-writing-review.sh と同じ拾い方に揃える
WRITE_IN_CMD = re.compile(
    r"""(?:>\|?|\btee(?:\s+-a)?)\s*['"]?([^\s'";|&<>]+\.md)\b"""
    r"""|\bsed\s+-i\s+(?:''\s+)?(?:-e\s+)?(?:'[^']*'|"[^"]*"|\S+)\s+(?:-e\s+\S+\s+)*([^\s'";|&<>]+\.md)\b""")
# 先頭で cd していれば、相対パスはそこから解決する
CD_PREFIX = re.compile(r"""^\s*cd\s+['"]?([^\s'";|&]+)['"]?\s*&&""")


def written_paths():
    """このターン（最後に人が入力してから）に書いた .md のパス

    リポジトリの未コミットの .md を全部見ていた頃は、別のセッションが置いた
    ファイルや書きかけのファイルでも止まった。セッション全体の Write / Edit で
    絞っても、昔一度書いたファイルを別のセッションが書き換えると、その分で
    止まった。今のターンに書いたものだけを見る。
    Bash で書いた分は、リダイレクト・sed -i・tee の書き込み先から拾う。
    名前が出てきた .md を全部拾っていた頃は、ls で時刻を見ただけの他人の
    未追跡の .md でも止まった"""
    out = set()
    try:
        f = io.open(str(d.get("transcript_path", "")), encoding="utf-8")
    except Exception:
        return out
    with f:
        for line in f:
            if '"tool_use"' not in line and '"human"' not in line:
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get("type") == "user" and (e.get("origin") or {}).get("kind") == "human":
                out = set()
                continue
            base = e.get("cwd") or d.get("cwd") or os.getcwd()
            for b in (e.get("message") or {}).get("content") or []:
                if not (isinstance(b, dict) and b.get("type") == "tool_use"):
                    continue
                inp = b.get("input") or {}
                if b.get("name") in ("Write", "Edit", "MultiEdit") and inp.get("file_path"):
                    out.add(os.path.realpath(inp["file_path"]))
                elif b.get("name") == "Bash":
                    cmd = str(inp.get("command", ""))
                    cd = CD_PREFIX.match(cmd)
                    if cd:
                        base = os.path.join(base, os.path.expanduser(cd.group(1)))
                    for m in WRITE_IN_CMD.finditer(cmd):
                        out.add(os.path.realpath(os.path.join(base, os.path.expanduser(m.group(1) or m.group(2)))))
    return out


def uncommitted(path):
    """git の管理下にあり、HEAD から変わっているか（未追跡を含む）"""
    try:
        r = subprocess.run(["git", "-C", os.path.dirname(path), "status",
                            "--porcelain", "--", os.path.basename(path)],
                           capture_output=True, text=True, timeout=5)
    except Exception:
        return False
    return r.returncode == 0 and r.stdout.strip() != ""


def edited_markdown():
    """このターンに書いた .md とコードのファイルのうち、まだコミットしていないもの。
    コードはコメントだけを見る（check-japanese-spacing.py の check_text）"""
    return sorted(p for p in written_paths()
                  if p.endswith((".md",) + mod.CODE) and os.path.exists(p) and uncommitted(p))


def _load(mod_name, file_name):
    spec = importlib.util.spec_from_file_location(mod_name, os.path.join(os.environ.get("HOOK_DIR", ""), file_name))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


try:
    links = _load("links", "check-reference-links.py")
    report = _load("report", "check-report-format.py")
except Exception:
    links = report = None


def link_hits(text):
    """Markdown の地の文の、リンクにしていない課題キーと報告の書式（URL の直後の約物）。
    会話にだけ掛けていた検査をファイルにも掛ける。コードブロックの中は NG の例や原文なので見ない"""
    out, fence = [], False
    if not links:
        return out
    for n, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        for cat, _k in links.check_links(line):
            if cat == "リンクにしていない課題キー":
                out.append((n, cat, line.strip()))
        for cat, _t in report.check_report(re.sub(r"`[^`]*`", " ", line)):
            out.append((n, cat, line.strip()))
    return out


def all_hits(path, text):
    hits_ = mod.check_text(text, code=not path.endswith(mod.MARKDOWN))
    if path.endswith(mod.MARKDOWN):
        hits_ += link_hits(text)
    return hits_


def head_hits(path):
    """HEAD の時点の指摘。既存分は数えないため"""
    d2 = os.path.dirname(path)
    try:
        top = subprocess.run(["git", "-C", d2, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=5)
        rel = os.path.relpath(path, top.stdout.strip())
        show = subprocess.run(["git", "-C", d2, "show", "HEAD:" + rel],
                              capture_output=True, text=True, timeout=5)
    except Exception:
        return set()
    if show.returncode != 0:
        return set()
    return {(name, src) for _n, name, src in all_hits(path, show.stdout)}


for path in edited_markdown()[:20]:
    was = head_hits(path)
    name_only = os.path.basename(path)
    try:
        text = io.open(path, encoding="utf-8").read()
    except Exception:
        continue
    for n, name, src in all_hits(path, text):
        if (name, src) not in was:
            hits.append((name_only, n, name, src))

if not hits:
    raise SystemExit(0)

# 止める回数は入口の stop-checks.sh が数える（Stop フック共通）

# 指摘と例はコードブロックへ入れる。裸で置くと、受け取った側が引用した
# だけで再び検査に当たる（実際に差し戻しが2回になった）。NG 例は
# 「違反した形で正しい」ので、囲まないと自分自身を弾く
lines = ["**表記が規約に反しています。直してから返してください**", "", "```"]
for where, n, name, src in hits[:6]:
    lines.append("%s %d行目 %s" % (where, n, name))
    lines.append("    %s" % src[:72])
if len(hits) > 6:
    lines.append("ほか %d件" % (len(hits) - 6))
lines += ["```",
          "",
          "```",
          "数値と単位・日本語と数字のあいだは詰める",
          "  NG: 2 万件   OK: 2万件",
          "全角の約物の後ろは空けない",
          "  NG: 「変更履歴」 hoge   OK: 「変更履歴」hoge",
          "インラインコードの直後に全角の約物を置かない",
          "  NG: `code`（説明）   OK: `code` （説明）",
          "ダッシュは使わず句点で切る",
          "```",
          "  → ~/.claude/references/japanese_notation.md"]
sys.stderr.write("\n".join(lines))
raise SystemExit(2)
PY
