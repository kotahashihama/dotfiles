#!/bin/bash
#
# push で削った設定ファイルのコメントを拾う PostToolUse フック。
#
# 削った記述には行き先が要る。仕組み上の制約なら（不変の WHY）コードコメント、
# 移行の事情や過渡期の措置なら（移ろう WHY）PR の [fyi] へ置く
# （write_invariant_why_in_code.md）。
#
# 削る手と置く手は別のタイミングで動く。インラインコメントはコミットを指すので
# push するまで付けられず、push した時点では別のことを考えている。ルール側は
# その時間差を原因として書いているが、それでも落ちる。
#
# 発火率を2つのリポジトリで測った。どちらも読み飛ばされる域（30%）の手前。
#
#   FE のリポジトリの main 直近100コミット  … 6件（うち2件はファイル移動の
#                                               ペアで、閾値20行で落ちる）
#   dotfiles の直近100コミット              … 0件（対象拡張子を触ったのは25件、
#                                               コメントは足し57行に対し消し8行）
#
# 止めることはできない（push 済み）。気づかせるだけ。
#
set -u

payload=$(cat)

python3 - "$payload" <<'PY'
import json, re, subprocess, sys

try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

cmd = (d.get("tool_input") or {}).get("command", "")
if not re.search(r"\bgit\s+push\b", cmd):
    sys.exit(0)


def run(args):
    """成功したときだけ stdout を返す。失敗と不在は呼び側で区別しない。

    このフックは鳴らすかどうかしか決めないので、リポジトリ外・初回 push・
    git が無い、のどれでも「鳴らさない」で正しい。
    """
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=10)
    except Exception:
        return None
    return p.stdout if p.returncode == 0 else None


# push 先のブランチを、コマンドの形から拾う。実際に打たれる形を15通り並べて
# 検証した（パイプ・リダイレクト・前段のコマンド・引数の省略）。
#
#   git push                       -> 現在のブランチの upstream
#   git push origin                -> 同じ
#   git push origin <branch>       -> <branch>
#   git push origin HEAD:<branch>  -> <branch>（detached HEAD から書くときの形）
#
# パイプの後ろで割らないと `| tail -3` の tail を枝名に取り違える。
# リダイレクトも行き先ごと落とさないとファイル名を拾う。
segs = re.split(r"\|\||&&|[|;]", cmd)
seg = next((s for s in segs if re.search(r"\bgit\s+push\b", s)), None)
if seg is None:
    sys.exit(0)
seg = re.sub(r"\d?>>?[|&]?\s*\S*", " ", seg)

words = [w for w in seg.split() if not w.startswith("-")]
try:
    i = words.index("push")
except ValueError:
    sys.exit(0)
rest = words[i + 1:]

if len(rest) >= 2:
    branch = rest[-1].split(":")[-1]
else:
    up = run(["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"])
    branch = up.strip().split("/", 1)[-1] if up else None
if not branch:
    sys.exit(0)

# @{1} は push 前のリモート追跡位置。worktree からの push でも同じ位置を指す
# （本体の .git/logs/refs/remotes/ を共有するため。実測で確認）。
ref = "origin/" + branch
if run(["git", "rev-parse", "--verify", "--quiet", ref + "@{1}"]) is None:
    sys.exit(0)

# JSON はコメントを持たないので対象から外す。
diff = run(["git", "diff", "%s@{1}..%s" % (ref, ref), "--", "*.yml", "*.yaml", "*.toml"])
if not diff:
    sys.exit(0)

dels, adds, files = [], 0, set()
path = None
for line in diff.splitlines():
    # `+++ b/` はファイル削除だと `+++ /dev/null` になるので、両方のパスを持つ
    # `diff --git` の行から取る。実際に消えた設定ファイルで空になっていた
    if line.startswith("diff --git "):
        m = re.match(r"diff --git a/(\S+) b/(\S+)", line)
        path = m.group(2) if m else None
    elif re.match(r"^-\s*#", line):
        dels.append(line[1:].strip())
        if path:
            files.add(path)
    elif re.match(r"^\+\s*#", line):
        adds += 1

# 追加のほうが多ければ書き換え。行き先は要らない。
if not dels or adds >= len(dels):
    sys.exit(0)

# ファイルの移動は片側が丸ごと削除に見える。実測で206行のものがあった。
if len(dels) > 20:
    sys.exit(0)

msg = (
    "この push で設定ファイルの行頭コメントを%d行削っています（追加は%d行）。対象は %s。\n"
    "**削った記述の行き先が残っていないか確かめてください。** 仕組み上の制約なら"
    "コードコメントへ、移行の事情や過渡期の措置なら**この push のコミットを指して "
    "PR へ `[fyi]` を付ける**（write_invariant_why_in_code.md の「削るときは、"
    "置くところまでを1つの作業にする」）。\n"
    "削った内容: %s"
) % (
    len(dels), adds, "、".join(sorted(files)) or "(不明)",
    " / ".join(x[:60] for x in dels[:3]) + (" ほか" if len(dels) > 3 else ""),
)

# additionalContext は Claude へ、systemMessage はユーザーの表示へ届く。
# 置くのは Claude なので、両方に出す。
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": msg,
    },
    "systemMessage": msg,
}, ensure_ascii=False))
PY
exit 0
