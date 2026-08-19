#!/bin/bash
#
# コマンドの形だけで判定できる禁止を弾く PreToolUse フック。
#
# 会話の文脈が要る禁止（明示指示があったか等）は扱わない。フックは
# 会話を見られないので、判定できるのは「そのコマンドの形」までになる。
#
# stdin に PreToolUse の JSON が来る。deny するときは exit 0 + JSON で返す
# （exit 2 でも弾けるが、理由を渡せるこちらを使う）。
#
set -u

payload=$(cat)
cmd=$(printf '%s' "$payload" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

deny() {
  python3 -c '
import json, sys
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": sys.argv[1],
}}, ensure_ascii=False))' "$1"
  exit 0
}

# 1) 既存ファイルへの `>` — noclobber で黙って失敗し、ループの中では
#    前の周回の内容が残ったまま後続が走る（verify_before_asserting.md）
#    `>|` `>>` `2>` `&>` `>(` は対象外。
# 引用符の中身を落としてから見る（`grep -c ">"` を誤検知しないため）
stripped=$(printf '%s' "$cmd" | python3 -c '
import sys, re
s = sys.stdin.read()
s = re.sub(r"\x27[^\x27]*\x27", "", s)   # シングルクォート
s = re.sub(r"\"[^\"]*\"", "", s)          # ダブルクォート
print(s)')

# /dev/null への破棄は上書きではないので対象外
stripped=$(printf '%s' "$stripped" | sed 's|>[[:space:]]*/dev/null||g')

# `>>` は追記なので対象外。`2>` `&>` `>|` `>(` も除く
if printf '%s' "$stripped" | grep -qE '(^|[^0-9&>|=-])>[^>|(=][[:space:]]*[^|(&[:space:]]|(^|[^0-9&>|=-])>[[:space:]]+[^|(&[:space:]]'; then
  deny 'リダイレクトは `>` ではなく `>|` を使ってください。noclobber が有効だと `>` は黙って失敗し、ループ内では前の周回の内容が残ったまま後続が走ります（verify_before_asserting.md）'
fi

# 2) `git add -A` / `git add .` — 設定系ファイルが意識せず混ざる
#    （ask_before_editing_claude_assets.md / no_auto_commit.md）
if printf '%s' "$stripped" | grep -qE 'git[[:space:]]+add[[:space:]]+(-A|--all|\.)([[:space:]]|$)'; then
  deny 'git add は対象ファイルを名指ししてください。-A / . は設定系ファイルを意識せず巻き込みます（ask_before_editing_claude_assets.md）'
fi

# 3) push の force 系 — 履歴を書き換える。指示があるときだけ手で打つ
#    （no_auto_commit.md / no_rebase_under_human_review.md）
if printf '%s' "$stripped" | grep -qE 'git[[:space:]]+push[^|;&]*(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  deny 'force push は履歴を書き換えます。人間のレビューが付いた PR では特に避けてください（no_rebase_under_human_review.md）。必要なら理由と対象を確認してから手で実行してください'
fi

exit 0
