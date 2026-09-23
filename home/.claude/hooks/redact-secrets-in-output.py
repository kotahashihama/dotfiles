#!/usr/bin/env python3
"""ツールの出力から秘匿値の形をした文字列を伏せてからモデルへ渡す PostToolUse フック"""
import json
import re
import sys

# 接頭辞で見分けられる形だけに絞る
# 長さだけで拾うと、ハッシュや ID まで伏せてしまい読めなくなる
PATTERNS = [
    ("private-key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.S)),
    ("anthropic", re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}")),
    ("openai", re.compile(r"sk-(?:proj-)?[A-Za-z0-9_-]{32,}")),
    ("github", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b|\bgithub_pat_[A-Za-z0-9_]{22,}")),
    ("aws", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("slack", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}")),
    ("google", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("stripe", re.compile(r"\b[sr]k_live_[A-Za-z0-9]{20,}")),
]


def redact(value, hits):
    if isinstance(value, str):
        for kind, pat in PATTERNS:
            value, n = pat.subn(f"[REDACTED:{kind}]", value)
            if n:
                hits[kind] = hits.get(kind, 0) + n
        return value
    if isinstance(value, list):
        return [redact(v, hits) for v in value]
    if isinstance(value, dict):
        return {k: redact(v, hits) for k, v in value.items()}
    return value


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    # 実測した入力は tool_response
    if "tool_response" not in payload:
        return
    hits = {}
    redacted = redact(payload["tool_response"], hits)
    # 変えていないのに返すと、並列に走る他のフックの書き換えを上書きしうる
    if not hits:
        return
    summary = "、".join(f"{k} {n}件" for k, n in hits.items())
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "updatedToolOutput": redacted,
            "additionalContext": (
                f"ツールの出力に秘匿値の形をした文字列があり、伏せてから渡しています（{summary}）。"
                "`[REDACTED:…]` の位置の原文はこちらからは読めません。"
                "値そのものを確かめる必要があるなら、存在の有無や長さだけを返す形で取り直してください（no_secret_values_in_output.md）"
            ),
        }
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
