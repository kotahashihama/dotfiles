#!/bin/bash
#
# git push の後に、push したブランチの open な PR があれば、本文と差分の照合を促す PostToolUse フック。
#
# PR に push すると差分が動くので、本文と補足コメントが古くなる。照合は /update-pr-description が持つ
# （keep_records_current.md）。規約はあったが、本文を手で部分的に直すだけで済ませる形が続いたので、
# push の直後に1回だけ思い出させる。
#
# 止めることはできない（実行済み）。気づかせるだけ。
#
set -u

payload=$(cat)

python3 - "$payload" <<'PY'
import json, os, re, shlex, subprocess, sys

try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

cmd = (d.get("tool_input") or {}).get("command", "")
if not re.search(r"\bgit\s+(?:-C\s+\S+\s+)?push\b", cmd) or "--dry-run" in cmd:
    sys.exit(0)

res = d.get("tool_response", d.get("tool_result", ""))
if isinstance(res, dict):
    out = "\n".join(str(res.get(k, "")) for k in ("stdout", "stderr"))
else:
    out = str(res)
# 何も動いていない・拒否された push は対象外
if "Everything up-to-date" in out or re.search(r"\[rejected\]|^error: failed to push", out, re.M):
    sys.exit(0)

# push したディレクトリ: `git -C <dir>` か `cd <dir> &&` を優先し、無ければフックの cwd
# パスのシェルの展開は `$(ghq root)` と `$HOME` / `~` だけを開く。どれも副作用が無い。
# それ以外の展開が残るなら黙って抜ける。cwd へ戻すと別のリポジトリの同名ブランチの PR を促しかねず、
# 誤った PR を促すほうが、促さないより害が大きい
workdir = d.get("cwd") or os.getcwd()
m = re.search(r"\bgit\s+-C\s+(\"[^\"]*\"|'[^']*'|\S+)\s+push\b", cmd) or re.search(
    r"\bcd\s+(\"[^\"]*\"|'[^']*'|\S+)\s*&&[^;|]*\bgit\s+push\b", cmd)
if m:
    target = m.group(1).strip("'\"")
    if "$(ghq root)" in target:
        try:
            root = subprocess.check_output(["ghq", "root"], text=True, stderr=subprocess.DEVNULL, timeout=5).strip()
        except Exception:
            sys.exit(0)
        target = target.replace("$(ghq root)", root)
    target = os.path.expanduser(target.replace("${HOME}", "~").replace("$HOME", "~"))
    if re.search(r"[$`]", target):
        sys.exit(0)
    workdir = target

def git(*args):
    try:
        return subprocess.check_output(["git", "-C", workdir, *args], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

# push した先のブランチ: 出力の「-> <branch>」、無ければコマンドの refspec、それも無ければ今のブランチ
branches = set(re.findall(r"->\s+(\S+)", out))
if not branches:
    part = cmd[re.search(r"\bgit\s+(?:-C\s+\S+\s+)?push\b", cmd).end():]
    part = re.split(r"[;&|]", part)[0]
    try:
        toks = [t for t in shlex.split(part) if not t.startswith("-")]
    except ValueError:
        toks = []
    for t in toks[1:]:  # 先頭はリモート名
        branches.add(t.split(":", 1)[1] if ":" in t else t)
    if not branches:
        cur = git("branch", "--show-current")
        if cur:
            branches.add(cur)
branches = {re.sub(r"^refs/heads/", "", b) for b in branches if b and b != "HEAD"}
if not branches:
    sys.exit(0)

url = git("remote", "get-url", "origin")
m = re.search(r"github\.com[:/]([^/]+/[^/.]+?)(?:\.git)?$", url)
if not m:
    sys.exit(0)
repo = m.group(1)

prs = []
for b in sorted(branches):
    try:
        j = subprocess.check_output(
            ["gh", "pr", "list", "-R", repo, "--head", b, "--state", "open", "--json", "number,url"],
            text=True, stderr=subprocess.DEVNULL, timeout=20)
        prs += [p for p in json.loads(j)]
    except Exception:
        pass
if not prs:
    sys.exit(0)

names = "・".join(f"#{p['number']}" for p in prs)
msg = (f"{repo} の {names} に push しました。差分が動いたので、本文と自分の補足コメントを "
       "`/update-pr-description` で照合してください（keep_records_current.md）。"
       "手で一部を直すだけでは、Step 5 の照合（数値・識別子・主張・書式）が抜けます")
print(json.dumps({
    "hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": msg},
}, ensure_ascii=False))
PY
exit 0
