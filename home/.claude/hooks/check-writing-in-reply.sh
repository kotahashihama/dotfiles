#!/bin/bash
#
# 応答と、このターンで編集した Markdown の表記を検査する Stop フック。
#
# 書式の規約は「こちらが書くものすべて」が対象だが、フックが掛かるのは
# ファイルへの書き込みと GitHub への投稿だけだった。**書く量が最も多いのは
# 会話**で、そこに検査が無い（no_secret_values_in_output.md の「効くのは
# 形が決まっている経路だけ」と同じ穴）。
#
# ファイル側もここで見る。PostToolUse は「知らせる」だけで止められない
# （公式ドキュメント: PostToolUse cannot block; the tool already ran）ので、
# 書いた直後の指摘を無視できてしまう。Stop なら直すまで終われない。
#
# 1 プロンプトにつき 1 回しか止めない。誤検知しても 1 ターン余計に進むだけ。
#
set -u

payload=$(cat)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOOK_DIR

python3 - "$payload" <<'PY'
import importlib.util
import json, os, subprocess, sys, tempfile

try:
    d = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)

msg = str(d.get("last_assistant_message", ""))
pid = str(d.get("prompt_id", ""))
if not msg or not pid:
    raise SystemExit(0)

# 判定はファイル・GitHub 投稿と同じものを使う。書く場所ごとに実装を分けると
# 判定がずれる
path = os.path.join(os.environ["HOOK_DIR"], "check-japanese-spacing.py")
try:
    spec = importlib.util.spec_from_file_location("cjs", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
except Exception:
    raise SystemExit(0)

hits = [("応答", n, name, src) for n, name, src in mod.check_text(msg)]


def edited_markdown():
    """このリポジトリで未コミットの .md を返す"""
    try:
        r = subprocess.run(["git", "status", "--porcelain", "--", "*.md"],
                           capture_output=True, text=True, timeout=5,
                           cwd=d.get("cwd") or os.getcwd())
        top = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=5,
                             cwd=d.get("cwd") or os.getcwd())
    except Exception:
        return []
    if r.returncode != 0 or top.returncode != 0:
        return []
    root = top.stdout.strip()
    out = []
    for line in r.stdout.split("\n"):
        if len(line) > 3 and line[0] != "D" and line[1] != "D":
            out.append(os.path.join(root, line[3:].strip().strip(chr(34))))
    return [p for p in out if p.endswith(".md") and os.path.exists(p)]


def head_hits(path):
    """HEAD 版の指摘。既存分は数えないため"""
    d2 = os.path.dirname(path)
    try:
        top = subprocess.run(["git", "-C", d2, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=5)
        rel = os.path.relpath(path, top.stdout.strip())
        show = subprocess.run(["git", "-C", d2, "show", "HEAD:" + rel],
                              capture_output=True, text=True, timeout=5)
    except Exception:
        return set()
    if show.returncode != 0:
        return set()
    return {(name, src) for _n, name, src in mod.check_text(show.stdout)}


for path in edited_markdown()[:20]:
    was = head_hits(path)
    name_only = os.path.basename(path)
    for n, name, src in mod.check(path):
        if (name, src) not in was:
            hits.append((name_only, n, name, src))

if not hits:
    raise SystemExit(0)

# 鍵は Stop フック共通。別々に持つと、同じターンで 2 本とも止めて
# 差し戻しが 2 回になる。見送った側は次のターンで拾う
mark = os.path.join(tempfile.gettempdir(), "claude-stopguard-" + pid)
if os.path.exists(mark):
    raise SystemExit(0)
open(mark, "w").close()

lines = ["**表記が規約に反しています。直してから返してください**", ""]
for where, n, name, src in hits[:6]:
    lines.append("- %s %d行目 %s" % (where, n, name))
    lines.append("    %s" % src[:72])
if len(hits) > 6:
    lines.append("- ほか %d件" % (len(hits) - 6))
lines += ["",
          "数値と単位・日本語と数字のあいだは詰める（`2 万件` → `2万件`）。",
          "全角の約物の後ろは空けない（`「変更履歴」 hoge` → `「変更履歴」hoge`）。",
          "ダッシュは使わず句点で切る。",
          "  → no_space_between_number_and_unit.md / no_em_dash_in_japanese.md"]
sys.stderr.write("\n".join(lines))
raise SystemExit(2)
PY
