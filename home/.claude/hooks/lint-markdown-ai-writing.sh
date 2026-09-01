#!/bin/bash
#
# 編集した Markdown を textlint と suiko に掛け、AI っぽい書き方を知らせる
# PostToolUse フック。
#
# 止めない。既存の指摘が137件あるので、error で止めると作業が進まない。
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
import io, json, os, re, subprocess, sys, tempfile

HOOK_DIR = os.environ["HOOK_DIR"]
TEXTLINT = os.path.join(HOOK_DIR, "textlint", "node_modules", ".bin", "textlint")
CONFIG = os.path.join(HOOK_DIR, "textlint", ".textlintrc.json")
SUIKO = os.path.join(HOOK_DIR, "suiko", "bin", "suiko")
SUIKO_DIR = os.path.join(HOOK_DIR, "suiko")

if not os.path.exists(TEXTLINT) and not os.path.exists(SUIKO):
    sys.exit(0)          # どちらも未導入なら黙って通す

WATCH = ["home/.claude/rules", "home/.claude/skills", "home/.claude/hooks",
         "home/.claude/agents", "home/.claude/CLAUDE.md"]


def changed_paths():
    """Bash で書き換えたときの対象。tool_input にパスが無いので git から拾う

    ヒアドキュメントや python -c で編集するとこの経路になる。1度報告した
    ものは (パス, mtime) で覚え、同じ内容で繰り返し出さない。
    """
    link = os.path.realpath(os.path.expanduser("~/.claude/settings.json"))
    try:
        repo = subprocess.run(["git", "-C", os.path.dirname(link),
                               "rev-parse", "--show-toplevel"],
                              capture_output=True, text=True, timeout=5)
        if repo.returncode != 0:
            return []
        root = repo.stdout.strip()
        r = subprocess.run(["git", "-C", root, "status", "--porcelain",
                            "--untracked-files=all", "--"] + WATCH,
                           capture_output=True, text=True, timeout=5)
    except Exception:
        return []
    seen_file = os.path.join(tempfile.gettempdir(),
                             "claude-lintmd-%s.seen" % os.environ.get("CLAUDE_SESSION_ID", "x"))
    try:
        seen = set(io.open(seen_file, encoding="utf-8").read().split("\n"))
    except OSError:
        seen = set()
    out, add = [], []
    for line in r.stdout.split("\n"):
        f = line[3:].strip().strip(chr(34))
        if not f.endswith(".md"):
            continue
        full = os.path.join(root, f)
        if not os.path.exists(full):
            continue
        mark = "%s\t%s" % (full, int(os.path.getmtime(full)))
        if mark in seen:
            continue
        out.append(full)
        add.append(mark)
    if add:
        with io.open(seen_file, "a", encoding="utf-8") as fh:
            fh.write("\n".join(add) + "\n")
    return out


try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
one = data.get("tool_input", {}).get("file_path", "")
paths = [one] if one and os.path.exists(one) else changed_paths()
if not paths:
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
        # 拡張子は元ファイルへ合わせる。表記の検査が .md かどうかで
        # 判定を変えるため、揃えないと HEAD 側と作業版で結果がずれる
        f = tempfile.NamedTemporaryFile("w", suffix=os.path.splitext(p)[1] or ".md",
                                        delete=False, encoding="utf-8")
        f.write(show.stdout)
        f.close()
        return f.name
    except Exception:
        return None


def lint(paths):
    """textlint を1回だけ起動し、ファイルごとの指摘を返す"""
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
        return {os.path.abspath(f["filePath"]): f["messages"]
                for f in json.loads(out)}
    except Exception:
        return {}


def suiko(paths):
    """suiko を1回だけ起動し、ファイルごとの指摘を返す

    textlint はパターン照合、suiko は形態素解析と統計で見る。取るものが
    違うので、重なる分（箇条書きのラベル・述語コロン）は後で束ねる。
    """
    if not os.path.exists(SUIKO):
        return {}
    try:
        r = subprocess.run([SUIKO, "lint", "--genre", "tech", "--no-config", "--json"] + paths,
                           capture_output=True, text=True, timeout=30,
                           cwd=SUIKO_DIR)
    except Exception:
        return {}
    out = (r.stdout or "").strip()
    # 1ファイルならオブジェクト、複数なら配列を返す
    if not out.startswith(("[", "{")):
        return {}
    try:
        docs = json.loads(out)
    except Exception:
        return {}
    if isinstance(docs, dict):
        docs = [docs]
    return {os.path.abspath(d["file"]): [{"ruleId": "suiko/" + f["category"],
                         "line": f["line"],
                         "message": f["detail"]} for f in d.get("findings", [])]
            for d in docs}


def spacing(paths):
    """日本語の表記。textlint も suiko も見ないので自前で判定する"""
    mod_path = os.path.join(HOOK_DIR, "check-japanese-spacing.py")
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("cjs", mod_path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
    except Exception:
        return {}
    out = {}
    for p in paths:
        try:
            out[os.path.abspath(p)] = [
                {"ruleId": "表記/" + name, "line": n, "message": name}
                for n, name, _src in mod.check(p)]
        except Exception:
            pass
    return out


def read(p):
    try:
        return open(p, encoding="utf-8").read().split("\n")
    except OSError:
        return []


def key(msg, lines):
    """行番号ではなく、ルールと該当行の中身で同一性を見る（行はずれる）"""
    src = (lines[msg["line"] - 1] if 0 < msg["line"] <= len(lines) else "").strip()
    return (msg["ruleId"], src)


def review(path):
    """1ファイルぶんの、この編集で新しく出た指摘を返す"""
    is_md = path.endswith(".md")
    base = head_version(path)
    targets = [path] + ([base] if base else [])
    results = lint(targets) if is_md else {}
    for extra in ((suiko(targets) if is_md else {}), spacing(targets)):
        for k, v in extra.items():
            results[k] = results.get(k, []) + v

    now_lines = read(path)
    now = {key(m, now_lines): m for m in results.get(os.path.abspath(path), [])}
    was = set()
    if base:
        was = {key(m, read(base)) for m in results.get(os.path.abspath(base), [])}
        try:
            os.unlink(base)
        except OSError:
            pass

    fresh = [(k, m) for k, m in now.items() if k not in was]
    # NG 例の行は規約に違反している形で正しい（github_one_sentence_per_line.md）
    fresh = [(k, m) for k, m in fresh
             if "❌" not in k[1] and "悪い例" not in k[1] and not k[1].startswith(">")]
    fresh.sort(key=lambda km: km[1]["line"])
    return fresh


out = []
for path in paths:
    fresh = review(path)
    if not fresh:
        continue
    name = os.path.basename(path)
    out.append("この編集で新しく出た指摘です（%s、%d件）。"
               "**止めていません。直すかどうかは中身で判断してください**"
               % (name, len(fresh)))
    for k, m in fresh[:8]:
        rule = m["ruleId"].split("/")[-1]
        out.append("- %s:%d  %s" % (name, m["line"], m["message"].split("。")[0]))
        out.append("    %s  → %s" % (k[1][:70], rule))
    if len(fresh) > 8:
        out.append("- ほか %d件" % (len(fresh) - 8))

if not out:
    sys.exit(0)

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "\n".join(out),
}}, ensure_ascii=False))
'
exit 0
