#!/bin/bash
#
# MCP か bee で文章を投稿する直前に、その本文を文章の点検に通したかを見る PreToolUse フック。
#
# 課題管理ツールの本文やコメントは、MCP の引数へ文字列で直に渡る。.md の
# 書き込みとしては拾えないので require-writing-review.sh（Stop）では見えず、
# 点検を通さない投稿が素通りした。投稿は取り消せないので、後で差し戻すのでは
# 遅い。投稿の前で止める。
#
# 通したかは、本文がこのターンに点検を通したファイルに含まれるかで見る。
# ファイルを経ずに /yomiyasu:yomiyasu へ本文を渡した場合は照合できないので、
# このターンに /yomiyasu:yomiyasu を呼んでいれば通す。
#
# Backlog の CLI（bee）で投稿するコマンドも同じく見る。本文はコマンドの引数・
# 標準入力に渡したファイル・bee api の -f の値から取り出す。
#
# Backlog の投稿では、その前に本文の PR 番号がリンクになっているかも見る。
#
set -u

payload=$(cat)

# Bash は呼び出しが多いので、bee を含まないものは Python を起動せずに通す
case "$payload" in
  *'"tool_name":"Bash"'* | *'"tool_name": "Bash"'*)
    case "$payload" in *bee*) ;; *) exit 0 ;; esac ;;
esac

python3 - "$payload" <<'PY'
import io, json, os, re, shlex, sys

try:
    d = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)

name = str(d.get("tool_name", ""))
inp = d.get("tool_input") or {}
TEXT_KEYS = ("description", "content", "comment", "body", "text")

# 本文を持って投稿・更新する bee のコマンド。title だけの変更や一覧・削除は投稿ではない
BEE_POST = re.compile(r"^(?:issue (?:comment|create|edit)|pr (?:comment|create|edit)|wiki (?:create|edit)|document create)$")
BEE_TEXT_OPTS = {"-b", "--body", "-d", "--description", "-c", "--comment", "--content"}


def bee_text(cmd, cwd):
    """bee の投稿なら (本文, 取り出せたか) を返す。投稿でなければ None"""
    base = cwd or os.getcwd()
    res = lambda p: os.path.join(base, os.path.expanduser(p))
    read = lambda p: io.open(res(p), encoding="utf-8").read()
    for seg_src in re.split(r"&&|\|\||;", cmd):
        parts = seg_src.split("|")
        for i, part in enumerate(parts):
            try:
                tok = shlex.split(part)
            except ValueError:
                continue
            if not tok or os.path.basename(tok[0]) != "bee":
                continue
            sub = " ".join(t for t in tok[1:3] if not t.startswith("-"))
            texts, found = [], False
            if tok[1:2] == ["api"]:
                method = next((tok[j + 1] for j, t in enumerate(tok) if t in ("-X", "--method") and j + 1 < len(tok)), "GET")
                if method.upper() not in ("POST", "PATCH", "PUT"):
                    continue
                for j, t in enumerate(tok):
                    if t in ("-f", "-F", "--field", "--raw-field") and j + 1 < len(tok) and "=" in tok[j + 1]:
                        k, v = tok[j + 1].split("=", 1)
                        if k in TEXT_KEYS:
                            found = True
                            texts.append(v)
            elif BEE_POST.match(sub):
                if {"--list", "--delete-last", "-h", "--help"} & set(tok):
                    continue
                for j, t in enumerate(tok):
                    if t in BEE_TEXT_OPTS and j + 1 < len(tok):
                        found = True
                        texts.append(tok[j + 1])
                if not found and i > 0:
                    found = True
                    texts.append("@-")   # 前のコマンドから標準入力で渡った本文
            else:
                continue
            if not found:
                return "", True   # 本文を持たない更新（題名・状態だけなど）
            out, ok = [], True
            for v in texts:
                m = re.fullmatch(r"\$\(\s*cat\s+(['\"]?)([^'\"]+)\1\s*\)", v)
                path = m.group(2) if m else (v[1:] if v.startswith("@") and v != "@-" else None)
                if v == "@-":
                    prev = shlex.split(parts[i - 1]) if i > 0 else []
                    path = prev[1] if prev[:1] == ["cat"] and len(prev) == 2 else None
                    if path is None:
                        ok = False
                        continue
                if path is not None:
                    try:
                        out.append(read(path))
                    except Exception:
                        ok = False
                else:
                    out.append(v)
            return "\n".join(out), ok
    return None


unresolved = False
if name == "Bash":
    r = bee_text(str(inp.get("command", "")), d.get("cwd"))
    if r is None:
        raise SystemExit(0)
    text, ok = r
    unresolved = not ok
    name = "bee（Backlog）"
else:
    # 読むだけのツール（get_・list_ 等）は投稿ではない
    if not name.startswith("mcp__") or re.search(r"__(?:get|list|search|query|count|read|export|resolve)[_a-z]*$", name):
        raise SystemExit(0)
    text = "\n".join(str(inp[k]) for k in TEXT_KEYS if isinstance(inp.get(k), str) and inp[k].strip())

# 生成者表示など投稿の直前に足す行があるので、短い行と引用の行は照合に使わない
rows = [r.strip() for r in text.splitlines() if len(r.strip()) >= 8 and not r.strip().startswith(">")]
if not rows and not unresolved:
    raise SystemExit(0)

# 課題管理ツールの本文では、PR を `[repo#123](URL)` のリンクで書く（no_space_between_number_and_unit.md）。
# MCP と bee の投稿には gh の本文の検査（lint-github-body.sh）が走らず、裸の #123 が2度素通りした。
# 「対応 PR: <URL>」の行とコードブロックの中は、裸で書く決まりか原文なので数えない。
if "backlog" in name:
    bare, fence = [], False
    for r in text.splitlines():
        s = r.strip()
        if s.startswith("```"):
            fence = not fence
            continue
        if fence or s.startswith("対応 PR:"):
            continue
        bare += re.findall(r"(?<![\w/\[#])#\d{3,5}\b", r)
    if bare:
        sys.stderr.write("\n".join([
            "**PR 番号がリンクになっていません**（%s）: %s" % (name, " ".join(sorted(set(bare)))),
            "",
            "課題管理ツールの本文では `[repo#123](https://github.com/<owner>/<repo>/pull/123)` の形にしてください。",
            "2回目より後に出てくる番号も同じです。「対応 PR: <URL>」の行はそのままでよい。",
            "  → no_space_between_number_and_unit.md の「URL は、Markdown ならリンクにして文に埋める」",
        ]))
        raise SystemExit(2)

REVIEW_IN_CMD = re.compile(r"yomiyasu_(?:lint|diff|check)\.py")
MD_ARG = re.compile(r"""(?:^|[\s'"=])([^\s'";|&<>]+\.md)\b""")
WRITE_IN_CMD = re.compile(r"""(?:>\|?|\btee(?:\s+-a)?)\s*['"]?([^\s'";|&<>]+\.md)\b""")
CD_PREFIX = re.compile(r"""^\s*cd\s+['"]?([^\s'";|&]+)['"]?\s*&&""")


def scan():
    """このターン（最後に人が入力してから）に点検を通したファイルと、/yomiyasu:yomiyasu を呼んだか"""
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

if unresolved:
    sys.stderr.write("\n".join([
        "**bee に渡す本文を、フックが読めません**（%s）" % name,
        "",
        "点検を通した .md を、`-b \"$(cat <ファイル>)\"`・`cat <ファイル> | bee ...`・`-f content=@<ファイル>` のどれかで渡してください。",
        "  → no_ai_style_writing.md の「文章の点検を通す場面と順序」",
    ]))
    raise SystemExit(2)

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
    "本文を .md に書き、/japanese-tech-writing を当ててから /yomiyasu:yomiyasu を通し、",
    "直した中身を渡して投稿し直してください。投稿は取り消せないので、前で止めています。",
    "  → no_ai_style_writing.md の「文章の点検を通す場面と順序」",
]))
raise SystemExit(2)
PY
