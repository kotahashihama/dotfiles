#!/bin/bash
#
# 取り消せない PR 操作を、ユーザーへ回す PreToolUse フック。
#
# どれも「ユーザーが明示指示したときだけ許される」規約なので、deny だと
# 正当な指示まで塞ぐ。ask ならユーザーが判断できる（decide_or_ask.md）。
#
# 状態を引くので gh を叩く。そのぶん遅いため、まず正規表現で門を作り、
# 該当しないコマンドは API を呼ばずに抜ける。
#
set -u

payload=$(cat)
printf '%s' "$payload" | python3 -c '
import json, os, re, subprocess, sys

try:
    p = json.loads(sys.stdin.read())
    cmd = p.get("tool_input", {}).get("command", "")
    CWD = p.get("cwd") or os.getcwd()
except Exception:
    sys.exit(0)
if not cmd:
    sys.exit(0)

# 門。ここに当たらないコマンドは API を呼ばずに抜ける
GATE = re.compile(r"gh\s+pr\s+(ready|edit|merge|close|comment|review)"
                  r"|gh\s+api[^|;&]*(requested_reviewers|/replies|/reviews)"
                  r"|git\s+rebase"
                  r"|git\s+push[^|;&]*(--force|--force-with-lease|\s-f(\s|$))")
if not GATE.search(cmd):
    sys.exit(0)


def gh(args, timeout=6):
    try:
        r = subprocess.run(["gh"] + args, capture_output=True, text=True,
                           timeout=timeout, cwd=CWD)
    except Exception:
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def me():
    return gh(["api", "user", "--jq", ".login"])


def pr_number():
    """コマンド中の番号か、無ければ現在のブランチの PR"""
    m = re.search(r"gh\s+pr\s+\w+\s+(\d+)", cmd)
    if m:
        return m.group(1)
    m = re.search(r"/pulls?/(\d+)", cmd)
    if m:
        return m.group(1)
    return gh(["pr", "view", "--json", "number", "--jq", ".number"])


def ask(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": reason,
    }}, ensure_ascii=False))
    sys.exit(0)


user = me()
num = pr_number()

# 1) 他人の PR。作成者が本人でなければ、読む以外は触らない
if num and user:
    author = gh(["pr", "view", num, "--json", "author", "--jq", ".author.login"])
    if author and author != user:
        ask("**#%s は %s の PR です。** 作成者が本人でない PR へは、状態を読む以外の操作を"
            "しません。指示が番号を名指ししていれば進めてよいですが、"
            "そうでなければ止めてください\n  → no_operating_on_others_prs.md" % (num, author))

# 2) レビュー中の履歴書き換え。他人のコメントが1件でもあれば足場が動く
if re.search(r"git\s+rebase|git\s+push[^|;&]*(--force|--force-with-lease|\s-f(\s|$))", cmd):
    if num and user:
        raw = gh(["pr", "view", num, "--json", "comments,reviews",
                  "--jq", "[(.comments[]?, .reviews[]?) | .author.login] | unique | join(\" \")"])
        if raw:
            others = [a for a in raw.split()
                      if a and a != user and not a.endswith("]")]
            if others:
                ask("**#%s には %s のレビューが付いています。** 履歴を書き換えると、"
                    "指摘が紐づいたコミットが消えて前回との差分も壊れます。"
                    "取り込むなら `git merge` を使ってください\n"
                    "  → no_rebase_under_human_review.md" % (num, " / ".join(others)))

# 3) レビュー依頼。通知が飛び、取り消しても戻らない
if re.search(r"gh\s+pr\s+ready|--add-reviewer|requested_reviewers", cmd):
    ask("**レビュアーへ通知が飛びます。** ready 化・再依頼・draft へ戻すことは、"
        "ユーザーが明示指示したときだけ実行します。準備が整っただけなら、"
        "状態を報告して指示を待ってください\n"
        "  → no_auto_ready_pr.md")

# 4) 人間のレビューコメントへの返信
if re.search(r"/replies|gh\s+pr\s+review\b", cmd):
    ask("**人間のレビューへの返信は、書き方も時機も当事者間のやりとりです。** "
        "返信してよいのは、ユーザーが明示指示したときと `/resolve-ai-reviews` で "
        "bot へ返すときだけ。修正はハッシュを会話で報告するに留めます\n"
        "  → no_auto_reply_human_review_comments.md")

sys.exit(0)
'
exit 0
