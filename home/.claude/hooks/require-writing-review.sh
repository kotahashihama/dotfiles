#!/bin/bash
#
# このターンに書いた Markdown を、文章の点検に通したかを見る Stop フック。
#
# 後から読まれる文章は /japanese-tech-writing → /yomiyasu に通す規約だが
# （no_ai_style_writing.md）、書き終えた区切りが来ない経路で抜けた。
# スクラッチパッドで書いて gh api でそのままコミットした規約文書が、
# 4本とも通さずに入っている。規約の文面を足しても同じ形で抜けるので、
# 形で止める。
#
# 通したかは、書いた後に /yomiyasu を呼んだか、同梱の検査を走らせたかで見る。
# 中身まで直したかは見ない（それは点検の側の仕事）。
#
set -u

payload=$(cat)

python3 - "$payload" <<'PY'
import io, json, os, re, sys, tempfile

try:
    d = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)

pid = str(d.get("prompt_id", ""))
if not pid:
    raise SystemExit(0)

HOME = os.path.expanduser("~")
# auto memory は会話の記録で、読み物ではない
SKIP_PREFIXES = (os.path.join(HOME, ".claude", "projects") + os.sep,)

# Bash で .md を書く・渡す形。読むだけのコマンド（cat・grep）は拾わない
WRITE_IN_CMD = re.compile(
    r"""(?:>\|?|\btee(?:\s+-a)?|--body-file|-F\s+body=@)\s*['"]?([^\s'";|&<>]+\.md)\b"""
    r"""|\bsed\s+-i\s+(?:''\s+)?(?:-e\s+)?(?:'[^']*'|"[^"]*"|\S+)\s+(?:-e\s+\S+\s+)*([^\s'";|&<>]+\.md)\b""")
REVIEW_IN_CMD = re.compile(r"yomiyasu_(?:lint|diff)\.py")
# 先頭で cd していれば、相対パスはそこから解決する
CD_PREFIX = re.compile(r"""^\s*cd\s+['"]?([^\s'";|&]+)['"]?\s*&&""")


def is_review_skill(name):
    name = str(name or "")
    return name == "yomiyasu" or name.endswith(":yomiyasu")


def scan():
    """このターン（最後に人が入力してから）で、最後に点検を通した後に書いた .md"""
    pending = []
    try:
        f = io.open(str(d.get("transcript_path", "")), encoding="utf-8")
    except Exception:
        return pending
    with f:
        for line in f:
            if '"tool_use"' not in line and '"human"' not in line:
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get("type") == "user" and (e.get("origin") or {}).get("kind") == "human":
                pending = []
                continue
            base = e.get("cwd") or d.get("cwd") or os.getcwd()
            for b in (e.get("message") or {}).get("content") or []:
                if not (isinstance(b, dict) and b.get("type") == "tool_use"):
                    continue
                name = b.get("name")
                inp = b.get("input") or {}
                if name == "Skill" and is_review_skill(inp.get("skill")):
                    pending = []
                    continue
                if name in ("Write", "Edit", "MultiEdit"):
                    p = str(inp.get("file_path", ""))
                    if p.endswith(".md"):
                        pending.append(os.path.realpath(p))
                elif name == "Bash":
                    cmd = str(inp.get("command", ""))
                    if REVIEW_IN_CMD.search(cmd):
                        pending = []
                        continue
                    cd = CD_PREFIX.match(cmd)
                    if cd:
                        base = os.path.join(base, os.path.expanduser(cd.group(1)))
                    for m in WRITE_IN_CMD.finditer(cmd):
                        p = m.group(1) or m.group(2)
                        pending.append(os.path.realpath(os.path.join(base, os.path.expanduser(p))))
    seen, out = set(), []
    for p in pending:
        if p in seen or p.startswith(SKIP_PREFIXES):
            continue
        seen.add(p)
        out.append(p)
    return out


files = scan()
if not files:
    raise SystemExit(0)

# 鍵は Stop フック共通（check-writing-in-files.sh と同じ）。上限も揃える
mark = os.path.join(tempfile.gettempdir(), "claude-stopguard-" + pid)
try:
    done = int(io.open(mark, encoding="utf-8").read().strip() or 0)
except Exception:
    done = 0
if done >= 3:
    raise SystemExit(0)
io.open(mark, "w", encoding="utf-8").write(str(done + 1))

lines = ["**書いた Markdown を、文章の点検に通していません**", "", "```"]
for p in files[:6]:
    lines.append(p.replace(HOME, "~", 1))
if len(files) > 6:
    lines.append("ほか %d件" % (len(files) - 6))
lines += ["```",
          "",
          "/japanese-tech-writing を当ててから /yomiyasu を通し、直してから返してください。",
          "後から読まれる文章（README・docs/・ルール・スキル・PR 本文・コメント）は、短くても対象です。",
          "読まれない下書き（使い捨てのメモ・テスト用の入力）なら、その旨を1行書いて終えてください。",
          "  → no_ai_style_writing.md の「文章の点検を通す場面と順序」"]
sys.stderr.write("\n".join(lines))
raise SystemExit(2)
PY
