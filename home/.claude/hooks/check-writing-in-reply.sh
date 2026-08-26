#!/bin/bash
#
# 会話への応答の表記を検査する Stop フック。
#
# 書式の規約は「こちらが書くものすべて」が対象だが、フックが掛かるのは
# ファイルへの書き込みと GitHub への投稿だけだった。**書く量が最も多いのは
# 会話**で、そこに検査が無い（no_secret_values_in_output.md の「効くのは
# 形が決まっている経路だけ」と同じ穴）。
#
# 1 プロンプトにつき 1 回しか止めない。誤検知しても 1 ターン余計に進むだけ。
#
set -u

payload=$(cat)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOOK_DIR

python3 - "$payload" <<'PY'
import importlib.util
import json, os, sys, tempfile

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

hits = mod.check_text(msg)
if not hits:
    raise SystemExit(0)

mark = os.path.join(tempfile.gettempdir(), "claude-writingguard-" + pid)
if os.path.exists(mark):
    raise SystemExit(0)
open(mark, "w").close()

lines = ["**応答の表記が規約に反しています。直してから返してください**", ""]
for n, name, src in hits[:6]:
    lines.append("- %d 行目 %s" % (n, name))
    lines.append("    %s" % src[:72])
if len(hits) > 6:
    lines.append("- ほか %d 件" % (len(hits) - 6))
lines += ["",
          "数値と単位・日本語と数字のあいだは詰める（`2 万件` → `2万件`）。",
          "全角の約物の後ろは空けない（`「変更履歴」 hoge` → `「変更履歴」hoge`）。",
          "ダッシュは使わず句点で切る。",
          "  → no_space_between_number_and_unit.md / no_em_dash_in_japanese.md"]
sys.stderr.write("\n".join(lines))
raise SystemExit(2)
PY
