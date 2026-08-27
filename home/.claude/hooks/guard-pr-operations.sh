#!/bin/bash
#
# 他人の成果物を壊しうる PR 操作を、ユーザーへ回す PreToolUse フック。
#
# 見るのは2つだけ。他人の PR へ痕跡を残す操作と、レビューが付いた PR の
# 履歴書き換え。どちらも指示があっても、対象を取り違えていれば戻せない。
#
# 自分の PR への操作は止めない。ready 化・再依頼・レビュー返信は規約が
# 「明示指示のみ」を定めており、打つのは指示があった後だけになる。
#
# deny ではなく ask にするのは、正当な指示まで塞がないため（decide_or_ask.md）。
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
GATE = re.compile(r"gh\s+pr\s+(ready|edit|merge|close|comment)"
                  r"|gh\s+api[^|;&]*(requested_reviewers|/replies)"
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

# 1) 他人の PR。作成者が本人でなければ、読む以外は触らない。
#
# レビューの投稿（ `gh pr review` / `gh api .../pulls/N/reviews` ）は門で外してある。
# no_operating_on_others_prs.md が「レビューを書くことは読む側の行為で、本ルールの
# 対象外」としており、止めると /review-pr のたびに引っかかる。
#
# 読み取りはここで外す。`gh api` は既定が GET なので、書き込みメソッドも
# フィールド指定も無ければ状態を引いているだけで、規約が認める「読む」に当たる。
WRITES = re.compile(r"(-X|--method)\s*(POST|PUT|PATCH|DELETE)|\s-[fF]\s", re.I)
is_read_only_api = bool(re.search(r"gh\s+api\b", cmd)) and not WRITES.search(cmd)
if num and user and not is_read_only_api:
    author = gh(["pr", "view", num, "--json", "author", "--jq", ".author.login"])
    if author and author != user:
        ask("**#%s は %s の PR です。** 作成者が本人でない PR へは、状態を読む以外の操作を"
            "しません。指示が番号を名指ししていれば進めてよいですが、"
            "そうでなければ止めてください\n  → no_operating_on_others_prs.md" % (num, author))

# 2) レビュー中の履歴書き換え。他人のコメントが1件でもあれば足場が動く
if re.search(r"git\s+rebase|git\s+push[^|;&]*(--force|--force-with-lease|\s-f(\s|$))", cmd):
    if num and user:
        # bot の判定は `user.type` で行う。`gh pr view --json comments` の
        # author は bot でも `is_bot` が null で、login も `github-actions`
        # （ `[bot]` が付かない）ため、名前では人間と見分けが付かない。
        JQ = "[.[] | select(.user.type == \"User\") | .user.login] | unique | join(\" \")"
        raw = " ".join(filter(None, [
            gh(["api", "repos/{owner}/{repo}/pulls/%s/reviews" % num, "--jq", JQ]),
            gh(["api", "repos/{owner}/{repo}/issues/%s/comments" % num, "--jq", JQ]),
        ]))
        if raw:
            others = sorted({a for a in raw.split() if a and a != user})
            if others:
                ask("**#%s には %s のレビューが付いています。** 履歴を書き換えると、"
                    "指摘が紐づいたコミットが消えて前回との差分も壊れます。"
                    "取り込むなら `git merge` を使ってください\n"
                    "  → no_rebase_under_human_review.md" % (num, " / ".join(others)))

# 自分の PR への ready 化・再依頼・レビュー返信は、ここでは止めない。
#
# どれも規約が「明示指示のみ」を定めているので、打つのは指示があった後だけになる。
# フックが重ねて聞くと、指示どおりに動いた回が毎回止まる。
#
# 残した2つは性質が違う。1) は他人の成果物へ痕跡を残す操作、2) は取り消せず
# 相手のレビューが紐づいたコミットごと壊す。どちらも指示があっても確かめる価値がある。

sys.exit(0)
'
exit 0
