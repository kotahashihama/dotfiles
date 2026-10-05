#!/bin/bash
#
# このセッションが書いた Markdown の表記を検査する Stop フック。
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
# 1プロンプトにつき3回まで止める（下の stopguard の鍵の説明）。
#
set -u

payload=$(cat)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOOK_DIR

python3 - "$payload" <<'PY'
import importlib.util
import io, json, os, subprocess, sys, tempfile

try:
    d = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)

pid = str(d.get("prompt_id", ""))
if not pid:
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

hits = []


def written_paths():
    """このセッションが Write / Edit したファイルのパス

    リポジトリの未コミットの .md を全部見ていた頃は、別のセッションが置いた
    ファイルや書きかけのファイルでも止まった。直す立場に無いものを直させる
    ことになるので、自分が書いたものだけに絞る"""
    out = set()
    try:
        f = io.open(str(d.get("transcript_path", "")), encoding="utf-8")
    except Exception:
        return out
    with f:
        for line in f:
            if '"tool_use"' not in line:
                continue
            try:
                m = json.loads(line).get("message") or {}
            except Exception:
                continue
            for b in m.get("content") or []:
                if (isinstance(b, dict) and b.get("type") == "tool_use"
                        and b.get("name") in ("Write", "Edit", "MultiEdit")):
                    fp = (b.get("input") or {}).get("file_path")
                    if fp:
                        out.add(os.path.realpath(fp))
    return out


def uncommitted(path):
    """git の管理下にあり、HEAD から変わっているか（未追跡を含む）"""
    try:
        r = subprocess.run(["git", "-C", os.path.dirname(path), "status",
                            "--porcelain", "--", os.path.basename(path)],
                           capture_output=True, text=True, timeout=5)
    except Exception:
        return False
    return r.returncode == 0 and r.stdout.strip() != ""


def edited_markdown():
    """このセッションが書いた .md のうち、まだコミットしていないもの"""
    return sorted(p for p in written_paths()
                  if p.endswith(".md") and os.path.exists(p) and uncommitted(p))


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

# 鍵は Stop フック共通。別々に持つと、同じターンで2本とも止めて
# 差し戻しが2回になる。見送った側は次のターンで拾う
#
# 1回だけ止める形にしていたが、差し戻し後の応答の22%（59回中13回）が
# まだ違反していた。2回目を通すと同じ内容が2回表示される。
# 上限は3回。外すと直せない違反で往復が終わらない
mark = os.path.join(tempfile.gettempdir(), "claude-stopguard-" + pid)
try:
    done = int(io.open(mark, encoding="utf-8").read().strip() or 0)
except Exception:
    done = 0
if done >= 3:
    raise SystemExit(0)
io.open(mark, "w", encoding="utf-8").write(str(done + 1))

# 指摘と例はコードブロックへ入れる。裸で置くと、受け取った側が引用した
# だけで再び検査に当たる（実際に差し戻しが2回になった）。NG 例は
# 「違反した形で正しい」ので、囲まないと自分自身を弾く
lines = ["**表記が規約に反しています。直してから返してください**", "", "```"]
for where, n, name, src in hits[:6]:
    lines.append("%s %d行目 %s" % (where, n, name))
    lines.append("    %s" % src[:72])
if len(hits) > 6:
    lines.append("ほか %d件" % (len(hits) - 6))
lines += ["```",
          "",
          "```",
          "数値と単位・日本語と数字のあいだは詰める",
          "  NG: 2 万件   OK: 2万件",
          "全角の約物の後ろは空けない",
          "  NG: 「変更履歴」 hoge   OK: 「変更履歴」hoge",
          "インラインコードの直後に全角の約物を置かない",
          "  NG: `code`（説明）   OK: `code` （説明）",
          "ダッシュは使わず句点で切る",
          "```",
          "  → no_space_between_number_and_unit.md / no_em_dash_in_japanese.md"]
sys.stderr.write("\n".join(lines))
raise SystemExit(2)
PY
