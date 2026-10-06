#!/bin/bash
#
# MCP で文章を投稿する直前に、その本文を文章の点検に通したかを見る PreToolUse フック。
#
# 課題管理ツールの本文やコメントは、MCP の引数へ文字列で直に渡る。.md の
# 書き込みとしては拾えないので require-writing-review.sh（Stop）では見えず、
# 点検を通さない投稿が素通りした。投稿は取り消せないので、後で差し戻すのでは
# 遅い。投稿の前で止める。
#
# 通したかは、本文がこのターンに点検を通したファイルに含まれるかで見る。
# ファイルを経ずに /yomiyasu へ本文を渡した場合は照合できないので、
# このターンに /yomiyasu を呼んでいれば通す。
#
set -u

payload=$(cat)

python3 - "$payload" <<'PY'
import io, json, os, re, sys

try:
    d = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)

name = str(d.get("tool_name", ""))
inp = d.get("tool_input") or {}
# 読むだけのツール（get_・list_ 等）は投稿ではない
if not name.startswith("mcp__") or re.search(r"__(?:get|list|search|query|count|read|export|resolve)[_a-z]*$", name):
    raise SystemExit(0)

TEXT_KEYS = ("description", "content", "comment", "body", "text")
text = "\n".join(str(inp[k]) for k in TEXT_KEYS if isinstance(inp.get(k), str) and inp[k].strip())
# 生成者表示など投稿の直前に足す行があるので、短い行と引用の行は照合に使わない
rows = [r.strip() for r in text.splitlines() if len(r.strip()) >= 8 and not r.strip().startswith(">")]
if not rows:
    raise SystemExit(0)

REVIEW_IN_CMD = re.compile(r"yomiyasu_(?:lint|diff)\.py")
MD_ARG = re.compile(r"""(?:^|[\s'"=])([^\s'";|&<>]+\.md)\b""")
WRITE_IN_CMD = re.compile(r"""(?:>\|?|\btee(?:\s+-a)?)\s*['"]?([^\s'";|&<>]+\.md)\b""")
CD_PREFIX = re.compile(r"""^\s*cd\s+['"]?([^\s'";|&]+)['"]?\s*&&""")


def scan():
    """このターン（最後に人が入力してから）に点検を通したファイルと、/yomiyasu を呼んだか"""
    written, reviewed, skill = set(), set(), False
    try:
        f = io.open(str(d.get("transcript_path", "")), encoding="utf-8")
    except Exception:
        return reviewed, True   # 読めなければ止めない
    with f:
        for line in f:
            if '"tool_use"' not in line and '"human"' not in line:
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get("type") == "user" and (e.get("origin") or {}).get("kind") == "human":
                written, reviewed, skill = set(), set(), False
                continue
            base = e.get("cwd") or d.get("cwd") or os.getcwd()
            for b in (e.get("message") or {}).get("content") or []:
                if not (isinstance(b, dict) and b.get("type") == "tool_use"):
                    continue
                n, i = b.get("name"), b.get("input") or {}
                if n == "Skill" and str(i.get("skill", "")).split(":")[-1] == "yomiyasu":
                    skill = True
                    reviewed |= written
                    written = set()
                elif n in ("Write", "Edit", "MultiEdit") and str(i.get("file_path", "")).endswith(".md"):
                    p = os.path.realpath(i["file_path"])
                    written.add(p)
                    reviewed.discard(p)   # 点検の後に書き直した分は、点検済みに数えない
                elif n == "Bash":
                    cmd = str(i.get("command", ""))
                    cd = CD_PREFIX.match(cmd)
                    if cd:
                        base = os.path.join(base, os.path.expanduser(cd.group(1)))
                    res = lambda p: os.path.realpath(os.path.join(base, os.path.expanduser(p)))
                    if REVIEW_IN_CMD.search(cmd):
                        reviewed |= written | {res(m.group(1)) for m in MD_ARG.finditer(cmd)}
                        written = set()
                        continue
                    for m in WRITE_IN_CMD.finditer(cmd):
                        p = res(m.group(1))
                        written.add(p)
                        reviewed.discard(p)
    return reviewed, skill


reviewed, skill = scan()
if skill:
    raise SystemExit(0)

for p in reviewed:
    try:
        body = io.open(p, encoding="utf-8").read()
    except Exception:
        continue
    if sum(r in body for r in rows) >= 0.8 * len(rows):
        raise SystemExit(0)

sys.stderr.write("\n".join([
    "**投稿する文章を、文章の点検に通していません**（%s）" % name,
    "",
    "本文を .md に書き、/japanese-tech-writing を当ててから /yomiyasu を通し、",
    "直した中身を渡して投稿し直してください。投稿は取り消せないので、前で止めています。",
    "  → no_ai_style_writing.md の「文章の点検を通す場面と順序」",
]))
raise SystemExit(2)
PY
