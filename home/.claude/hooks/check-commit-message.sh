#!/bin/bash
#
# git commit のメッセージを、コミットの前に karma_commit_style.md に照らす PreToolUse フック。
#
# 見るのは形で決まる4点だけ。
#   - 生成者のトレーラー（ Co-Authored-By: Claude Code <noreply@anthropic.com> ）があるか
#   - トレーラーにモデル名（ Claude Opus など）を書いていないか
#   - subject が type(scope): の形か（ Merge と Revert は git が作るので見ない）
#   - subject に課題の番号を入れていないか
#
# dotfiles には git の commit-msg フックがあるが、ほかのリポジトリには無く、
# トレーラーの無いコミットとモデル名を書いたコミットが会話のログに数百件あった。
# メッセージを取り出せないとき（エディタを開く・変数で渡す）は止めない。
#
set -u

payload=$(cat)
case "$payload" in *"git"*"commit"*) ;; *) exit 0 ;; esac

python3 - "$payload" <<'PY'
import json, os, re, shlex, sys

try:
    d = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)
if d.get("tool_name") != "Bash":
    raise SystemExit(0)
cmd = str((d.get("tool_input") or {}).get("command", ""))
if not re.search(r"\bgit\b[^\n|;&]*\bcommit\b", cmd):
    raise SystemExit(0)

TRAILER = "Co-Authored-By: Claude Code <noreply@anthropic.com>"
TYPES = r"(feat|fix|refactor|perf|docs|style|test|build|ci|chore)"


def message():
    """コマンドからメッセージを取り出す。取れなければ None"""
    # ヒアドキュメントで -F - か -m "$(cat <<'EOF' ...)" に渡す形
    m = re.search(r"<<-?\s*'?\"?(\w+)'?\"?\n(.*?)\n\1\b", cmd, re.S)
    if m and re.search(r"\bcommit\b[^\n]*(?:-F\s*-|--file[= ]-|-m\s*\"\$\(cat)", cmd):
        return m.group(2)
    seg = re.search(r"\bgit\b[^\n|;&]*\bcommit\b[^\n|;&]*", cmd)
    try:
        tok = shlex.split(seg.group(0))
    except ValueError:
        return None
    if {"--no-edit", "--amend"} & set(tok) and "-m" not in tok and "-F" not in tok:
        return None
    parts = []
    for i, t in enumerate(tok):
        if t in ("-m", "--message") and i + 1 < len(tok):
            parts.append(tok[i + 1])
        elif t.startswith("--message="):
            parts.append(t.split("=", 1)[1])
        elif t in ("-F", "--file") and i + 1 < len(tok) and tok[i + 1] != "-":
            try:
                base = d.get("cwd") or os.getcwd()
                return open(os.path.join(base, os.path.expanduser(tok[i + 1])), encoding="utf-8").read()
            except Exception:
                return None
    return "\n\n".join(parts) if parts else None


msg = message()
if not msg or "$" in msg.split("\n", 1)[0]:
    raise SystemExit(0)
subject = msg.strip().split("\n", 1)[0].strip()
if subject.startswith(("Merge ", "Revert ")):
    raise SystemExit(0)

bad = []
if TRAILER not in msg:
    bad.append("生成者のトレーラーがありません。footer に `%s` を置きます" % TRAILER)
if re.search(r"Co-Authored-By:\s*Claude\s+(Opus|Sonnet|Haiku|Fable)", msg, re.I):
    bad.append("トレーラーにモデル名があります。クライアント名の `Claude Code` にします")
if not re.match(TYPES + r"(\([^)]+\))?!?: \S", subject):
    bad.append("subject が `type(scope): 要約` の形ではありません（%s）" % subject[:60])
# 課題キーの判定は check-reference-links.py に1か所で持たせる（ UTF-8 などを除く）
try:
    import importlib.util
    _spec = importlib.util.spec_from_file_location("links", os.path.expanduser("~/.claude/hooks/check-reference-links.py"))
    _links = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_links)
    keys = [m.group(0) for m in _links.ISSUE_KEY.finditer(subject)
            if len(m.group(1)) >= 2 and m.group(1) not in _links.NOT_ISSUE_PREFIXES]
except Exception:
    keys = []
if keys:
    bad.append("subject に課題の番号があります（%s）。番号は PR のタイトルと本文が持ちます" % " ".join(keys))
if not bad:
    raise SystemExit(0)

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "コミットメッセージが karma_commit_style.md から外れています。\n- " + "\n- ".join(bad)
        + "\nそのリポジトリの規約文書が別の書式を定めているなら、その旨を添えてユーザーへ確かめてください。",
}}, ensure_ascii=False))
PY
