#!/bin/bash
#
# GitHub へ投稿する本文を、書式の規約に照らして弾く PreToolUse フック。
#
# 対象は取り消せない投稿だけ。PR 説明・コメント・レビュー・issue の本文が
# 外部へ出た後は、消しても通知と記録が残る。ルールは読み飛ばせるが、
# ここは必ず走る（rule_conventions.md の「強制が要るなら hooks へ」）。
#
# 判定できるのは本文の形だけ。中身が適切かは扱わない。
#
set -u

payload=$(cat)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOOK_DIR
printf '%s' "$payload" | GH_LINT_MODE=check python3 -c '
import json, os, re, subprocess, sys

RAW = sys.stdin.read()
try:
    _p = json.loads(RAW)
    cmd = _p.get("tool_input", {}).get("command", "")
    CWD = _p.get("cwd") or os.getcwd()
except Exception:
    sys.exit(0)
if not cmd or not re.search(r"\bgh\s+(pr|issue|api)\b", cmd):
    sys.exit(0)

# 本文を投稿しないサブコマンドは対象外
if re.search(r"\bgh\s+(pr|issue)\s+(list|view|checks|status|diff|ready|close|merge)\b", cmd) \
        and not re.search(r"--body", cmd):
    sys.exit(0)


def bodies(cmd):
    """コマンド文字列から、投稿される本文の候補を取り出す"""
    found = []
    # 1) ヒアドキュメント（gh pr edit --body "$(cat <<EOF ... EOF)" が最も多い）
    for m in re.finditer(r"<<-?[\x27\"]?([A-Za-z_][A-Za-z0-9_]*)[\x27\"]?\n(.*?)\n\s*\1\b",
                         cmd, re.S):
        found.append(m.group(2))
    # 2) --body / -b / -f body= に続く引用符つきの値
    for m in re.finditer(r"(?:--body|-b|(?:-f|--field|--raw-field)\s+body)[= ]\s*"
                         r"([\x27\"])(.*?)\1", cmd, re.S):
        v = m.group(2)
        if "<<" not in v:
            found.append(v)
    # 3) --body-file のファイル実体
    for m in re.finditer(r"--body-file[= ]\s*([\x27\"]?)([^\s\x27\"]+)\1", cmd):
        try:
            found.append(open(m.group(2), encoding="utf-8").read())
        except OSError:
            pass
    return [f for f in found if f.strip()]


UNIT = (r"(?:万|億|千|百|つ|件|行|本|回|個|人|箇所|秒|分|時間|日|週|月|年|倍|割|"
        r"文字|字|語|種|通り|段|層|周|重|度|点|ファイル|ケース|パターン|コミット|"
        r"ページ|MB|GB|KB|TB|MiB|GiB|ms|%|vCPU|px)")
JA = r"[ぁ-んァ-ヶ一-龥々〜]"
YAKUMONO = r"[、。「」『』（）【】・？！]"

NOTE = "> このコメントは Claude Code を使って作成されています。"
NOTE_PR = "> この PR 説明は Claude Code を使って作成されています。"


def spacing(body):
    """日本語の表記。判定は check-japanese-spacing.py が持つ"""
    import importlib.util
    p = os.path.join(os.environ.get("HOOK_DIR", ""),
                     "check-japanese-spacing.py")
    if not os.path.exists(p):
        return []
    try:
        spec = importlib.util.spec_from_file_location("cjs", p)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        return m.check_text(body)
    except Exception:
        return []


def prose_lines(body):
    """自分が書いた地の文の行を (行番号, 生の行, コードを伏せた行) で返す

    除くのは、コードブロック・引用・HTML コメント。HTML コメントは PR
    テンプレートの固定文で、リポジトリ側の文章なので逐語のまま残す
    （github_one_sentence_per_line.md の例外）。
    """
    out, inblock, incomment = [], False, False
    for n, line in enumerate(body.split("\n"), 1):
        if line.lstrip().startswith("```"):
            inblock = not inblock
            continue
        opened = "<!--" in line
        closed = "-->" in line
        skip = inblock or incomment or opened or line.lstrip().startswith(">")
        if opened and not closed:
            incomment = True
        if closed:
            incomment = False
        if skip:
            continue
        out.append((n, line, re.sub(r"`[^`]*`", " ", line)))
    return out


def check(body):
    """規約違反を (規約名, 説明, 該当行) の一覧で返す"""
    hits = []
    stripped = body.strip()

    # コマンドコメントは本文をコマンド1行に保つ（github_command_comments.md）
    if re.fullmatch(r"/[a-z][a-z0-9-]*", stripped):
        return []

    lines = prose_lines(body)

    if "Claude Code を使って作成" not in body:
        hits.append(("github_note_generated_by_claude.md",
                     "末尾に生成者表示の Note ブロックが無い。次を本文の末尾へ空行1行を挟んで置く\n"
                     "  > [!NOTE]\n"
                     "  " + NOTE + "\n"
                     "  （PR 説明なら「" + NOTE_PR.lstrip("> ") + "」）", []))

    bad = [n for n, _r, l in lines if re.search(r"。\s*$", l)]
    if bad:
        hits.append(("github_one_sentence_per_line.md",
                     "行末に句点がある。1文で改行し、行末の 。 は落とす（？ と ！ は残す）",
                     bad))

    # 表記の判定は check-japanese-spacing.py に集約する。ここに書き写すと、
    # 識別子の除外（ `#3145 の ` `d8d6db797 で ` ）のような後からの修正が
    # 片方にしか入らない
    for n, name, _src in spacing(body):
        hits.append(("no_space_between_number_and_unit.md",
                     "表記が規約に反している（%s）" % name, [n]))

    # 対になる記法。1文1行なので、行内で閉じていなければ壊れている。
    # 一括置換の直後にだけ出る形で、読んでも気づけない
    bad = []
    for n, raw, _l in lines:
        # コードスパンを先に落とす。`.claude/rules/**` のようなグロブを数えない
        rest = re.sub(r"`[^`]*`", " ", raw)
        if rest.count("**") % 2 or rest.count("~~") % 2 or rest.count("`") % 2:
            bad.append(n)
    if bad:
        hits.append(("github_one_sentence_per_line.md",
                     "対になる記法が閉じていない（ `**` `~~` バッククォート）。"
                     "強調が行をまたいで効く。**読んでも気づけないので必ず数える**", bad))

    bad = [n for n, _r, l in lines if "——" in l]
    if bad:
        hits.append(("no_em_dash_in_japanese.md",
                     "ダッシュを使っている。句点で切って次の文にする", bad))

    bad = [n for n, _r, l in lines if re.search(r"\b(Closes|Fixes|Resolves)\s+#?\d", l, re.I)]
    if bad:
        hits.append(("github_rich_formatting.md",
                     "自動クローズのキーワードがある。マージした瞬間に対象が閉じる。"
                     "参照だけなら #123 と書く", bad))

    bad = [n for n, _r, l in lines
           if re.search(r"自分の言葉で|自分の判断で|AI が書|Claude が判断", l)]
    if bad:
        hits.append(("github_no_authorship_voice.md",
                     "書き手の帰属を匂わせる表現がある。変更そのものを主語にする", bad))

    bad = [n for n, _r, l in lines
           if re.search(r"(FE|BE|フロント|バック|別リポ|担当|先方)\s*(と|の)?\s*連携|合意済み|エージェント\s*(間|と)|担当セッション|別セッション|(マージ順|リリース)\s*(の)?\s*調整", l)]
    if bad:
        hits.append(("no_agent_coordination_in_pr.md",
                     "エージェント間の調整に触れている。成果物には状態だけを書く", bad))

    return hits


def orphan_refs(body):
    """owner を省略した #123 のうち、同一リポジトリに存在しないものを返す"""
    nums = {m.group(1) for m in re.finditer(r"(?<![\w/])#(\d+)", body)}
    if not nums:
        return []
    missing = []
    for n in sorted(nums, key=int):
        try:
            r = subprocess.run(["gh", "api", "repos/{owner}/{repo}/issues/" + n,
                                "--jq", ".number"],
                               capture_output=True, timeout=4, cwd=CWD, text=True)
        except Exception:
            return []                    # 引けないなら黙って通す
        if r.returncode == 0:
            continue
        # 404だけが「存在しない」。リポジトリを解決できない等は通す
        if "HTTP 404" not in (r.stderr or ""):
            return []
        missing.append(n)
    return missing


problems = []
for body in bodies(cmd):
    for rule, msg, lines in check(body):
        where = ("（%s行目）" % "・".join(map(str, lines[:6]))) if lines else ""
        problems.append("- %s%s\n  → %s" % (msg, where, rule))
    for n in orphan_refs(body):
        problems.append("- #%s が同一リポジトリに見つからない。他リポジトリなら "
                        "owner/repo#%s と書く\n  → github_cross_repo_reference.md"
                        % (n, n))

if not problems:
    sys.exit(0)

reason = ("GitHub へ投稿する本文が書式の規約に反しています。"
          "投稿は取り消せないので、直してから出してください。\n\n"
          + "\n".join(problems))
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": reason,
}}, ensure_ascii=False))
'
exit 0
