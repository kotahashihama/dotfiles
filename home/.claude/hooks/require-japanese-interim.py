#!/usr/bin/env python3
"""ツールを呼んだ直後に、その前に書いた途中経過の文が日本語かを見る PostToolUse フック

Stop の require-japanese-response.sh も途中経過を見るが、応答を終えるときにしか走らない。
途中経過はツールを呼ぶたびに画面へ出るので、英語の文が何本も出てから差し戻すことになっていた。
実際に、1回の応答で英語の途中経過が4本出たあとで差し戻され、ユーザーに「hook が効いていない」と言われた。
ツールを呼ぶたびに直前の文を見て、日本語以外なら次の1手の前に知らせる。

同じ文を2回知らせない（直さずに続けてツールを呼んでも、同じ指摘を繰り返さない）。
止める力は持たない（PostToolUse は知らせるだけ）。止めるのは Stop の検査の役目。
"""

import hashlib
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from japanese_prose import counts, foreign  # noqa: E402

# 会話ログは長いので、末尾だけを読む。直前の文はツールの呼び出しのすぐ前にある
TAIL_BYTES = 512 * 1024
# 途中経過の1本は短いので、Stop の検査（合計200字）より低く、塊1つで40字から見る
MIN_LETTERS = 40


def last_text(path):
    """いまの応答で最後に書いた地の文を返す。ユーザーの入力まで遡っても無ければ空"""
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as f:
            f.seek(max(0, size - TAIL_BYTES))
            lines = f.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return ""
    for line in reversed(lines):
        try:
            e = json.loads(line)
        except Exception:
            continue
        body = (e.get("message") or {}).get("content")
        # 人の入力（文字列の本文）まで来たら、いまの応答の外
        if e.get("type") == "user" and isinstance(body, str):
            return ""
        if e.get("type") != "assistant" or not isinstance(body, list):
            continue
        texts = [c.get("text", "") for c in body if isinstance(c, dict) and c.get("type") == "text"]
        if any(t.strip() for t in texts):
            return "\n".join(texts)
    return ""


def main():
    try:
        d = json.load(sys.stdin)
    except Exception:
        return
    transcript = str(d.get("transcript_path", ""))
    session = str(d.get("session_id", "")) or "nosession"
    if not transcript:
        return
    text = last_text(transcript)
    if not text:
        return
    kana, letters = counts(text)
    if letters < MIN_LETTERS or not foreign(kana, letters):
        return

    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
    mark = os.path.join(tempfile.gettempdir(), f"claude-interim-ja-{session}")
    try:
        seen = set(open(mark, encoding="utf-8").read().split())
    except OSError:
        seen = set()
    if digest in seen:
        return
    try:
        with open(mark, "a", encoding="utf-8") as f:
            f.write(digest + "\n")
    except OSError:
        pass

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": (
                "**直前に書いた途中経過の文が日本語以外の言語になっています**（ `settings.json` の `language` ）。"
                "識別子・コード・コマンド・URL・固有名詞は原語のままでよく、それ以外の文を日本語で書きます。"
                "次に書く途中経過から日本語にしてください。"
            ),
        }
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
