#!/bin/bash
#
# 編集した Markdown を textlint に掛け、AI っぽい書き方を知らせる PostToolUse フック。
#
# 止めない。既存の指摘が 137 件あるので、error で止めると作業が進まない。
# 書いている最中に届けば、直す判断はその場でできる。
#
# HEAD 版との差分を取り、**この編集で新しく出たものだけ**を返す。既存の
# 指摘を毎回並べると、自分が今入れた分が埋もれる。
#
set -u

payload=$(cat)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOOK_DIR

printf '%s' "$payload" | python3 -c '
import json, os, re, subprocess, sys, tempfile

HOOK_DIR = os.environ["HOOK_DIR"]
TEXTLINT = os.path.join(HOOK_DIR, "textlint", "node_modules", ".bin", "textlint")
CONFIG = os.path.join(HOOK_DIR, "textlint", ".textlintrc.json")

if not os.path.exists(TEXTLINT):
    sys.exit(0)          # 未インストールなら黙って通す（npm ci が済んでいない環境）

try:
    path = json.load(sys.stdin).get("tool_input", {}).get("file_path", "")
except Exception:
    sys.exit(0)
if not path.endswith(".md") or not os.path.exists(path):
    sys.exit(0)


def head_version(p):
    """HEAD 版を一時ファイルへ書き出す。無ければ None"""
    d = os.path.dirname(os.path.abspath(p))
    try:
        top = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=5)
        if top.returncode != 0:
            return None
        rel = os.path.relpath(os.path.abspath(p), top.stdout.strip())
        show = subprocess.run(["git", "-C", d, "show", "HEAD:" + rel],
                              capture_output=True, text=True, timeout=5)
        if show.returncode != 0:
            return None      # 新規ファイル。比較対象が無い
        f = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False,
                                        encoding="utf-8")
        f.write(show.stdout)
        f.close()
        return f.name
    except Exception:
        return None


def lint(paths):
    """textlint を 1 回だけ起動し、ファイルごとの指摘を返す"""
    try:
        r = subprocess.run([TEXTLINT, "-c", CONFIG, "-f", "json"] + paths,
                           capture_output=True, text=True, timeout=30,
                           cwd=os.path.join(HOOK_DIR, "textlint"))
    except Exception:
        return {}
    out = (r.stdout or "").strip()
    if not out.startswith("["):
        return {}            # 設定が読めない等。黙って通す
    try:
        return {f["filePath"]: f["messages"] for f in json.loads(out)}
    except Exception:
        return {}


base = head_version(path)
results = lint([path] + ([base] if base else []))


def key(msg, lines):
    """行番号ではなく、ルールと該当行の中身で同一性を見る（行はずれる）"""
    src = (lines[msg["line"] - 1] if 0 < msg["line"] <= len(lines) else "").strip()
    return (msg["ruleId"], src)


def read(p):
    try:
        return open(p, encoding="utf-8").read().split("\n")
    except OSError:
        return []


now_lines = read(path)
now = {key(m, now_lines): m for m in results.get(os.path.abspath(path),
                                                 results.get(path, []))}
was = set()
if base:
    was = {key(m, read(base)) for m in results.get(os.path.abspath(base),
                                                   results.get(base, []))}
    try:
        os.unlink(base)
    except OSError:
        pass

fresh = [(k, m) for k, m in now.items() if k not in was]

# NG 例の行は規約に違反している形で正しい（github_one_sentence_per_line.md）
fresh = [(k, m) for k, m in fresh
         if "❌" not in k[1] and "悪い例" not in k[1] and not k[1].startswith(">")]

if not fresh:
    sys.exit(0)

fresh.sort(key=lambda km: km[1]["line"])
name = os.path.basename(path)
out = ["この編集で新しく出た textlint の指摘です（%s、%d件）。"
       "**止めていません。直すかどうかは中身で判断してください**" % (name, len(fresh))]
for k, m in fresh[:8]:
    rule = m["ruleId"].split("/")[-1]
    out.append("- %s:%d  %s" % (name, m["line"], m["message"].split("。")[0]))
    out.append("    %s  → %s" % (k[1][:70], rule))
if len(fresh) > 8:
    out.append("- ほか %d件" % (len(fresh) - 8))

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "\n".join(out),
}}, ensure_ascii=False))
'
exit 0
