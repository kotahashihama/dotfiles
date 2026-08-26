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
nohd=$(printf '%s' "$cmd" | python3 -c '
import sys, re
s = sys.stdin.read()
s = re.sub(r"<<-?[\x27\"]?([A-Za-z_][A-Za-z0-9_]*)[\x27\"]?\n.*?\n\1\n", "\n", s, flags=re.S)
s = re.sub(r"<<-?[\x27\"]?([A-Za-z_][A-Za-z0-9_]*)[\x27\"]?\n.*\Z", "\n", s, flags=re.S)
print(s)')

stripped=$(printf '%s' "$nohd" | python3 -c '
import sys, re
s = sys.stdin.read()
# ヒアドキュメントの中身はシェルではない。別言語の比較演算子
# (len(x) > 5など) をリダイレクトと読まないよう、先に丸ごと落とす
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

# 3) 保護ブランチへの force push — 共有している履歴を壊す
#    （no_auto_commit.md / no_rebase_under_human_review.md）
#
#    作業ブランチへの force は止めない。スタックの下段が squash でマージ
#    されると上段の差分が壊れ、rebase --onto での復旧に force が要る。
#    ここを塞ぐと、正規の復旧手段が使えなくなる。
#
#    宛先は refspec から読む。書かれていなければ現在のブランチが宛先になる
#    ので、payload の cwd で引く。
if printf '%s' "$stripped" | grep -qE 'git[[:space:]]+push[^|;&]*(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  cwd=$(printf '%s' "$payload" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)

  target=$(CMD="$stripped" CWD="$cwd" python3 -c '
import os, re, subprocess

cmd = os.environ["CMD"]
# 最後の `git push` 以降を見る（&& で繋がれていても宛先はそこにある）
m = None
for m in re.finditer(r"git\s+push\b", cmd):
    pass
rest = cmd[m.end():] if m else ""
# `;` `&&` `|` より前で切る
rest = re.split(r"[;&|]", rest)[0]

args = [a for a in rest.split() if not a.startswith("-")]
refspecs = args[1:]          # args[0] は remote

dests = []
for r in refspecs:
    r = r.lstrip("+")
    dests.append(r.rsplit(":", 1)[-1] if ":" in r else r)

if not dests:
    try:
        b = subprocess.run(["git", "-C", os.environ["CWD"], "symbolic-ref", "--short", "HEAD"],
                           capture_output=True, text=True, timeout=2).stdout.strip()
        if b:
            dests = [b]
    except Exception:
        pass

# refs/heads/main のような書き方も畳む
print(" ".join(d.rsplit("/", 1)[-1] for d in dests))' 2>/dev/null)

  for t in $target; do
    case "$t" in
      main|master)
        deny "保護ブランチ（${t}）への force push は、共有している履歴を壊します。作業ブランチへの force は止めていないので、宛先を確かめてください。main を巻き戻す必要が本当にあるなら、理由を添えてユーザーへ確認してください（no_rebase_under_human_review.md）"
        ;;
    esac
  done
fi

# 4) 秘匿値そのものを出力する形 — 存在確認に値は要らない
#    （no_secret_values_in_output.md）。実際にトークンを会話へ出した経路。
SECRET='(KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL|AUTH|SEED|PRIVATE)'

# 4a) `.env` を丸ごと読む。`.env.example` / `.env.sample` は雛形なので除く
if printf '%s' "$stripped" | grep -qE '(^|[[:space:]|])(cat|bat|less|more|head|tail|open)[[:space:]]+[^|;&]*\.env([[:space:]]|$)'; then
  deny '`.env` を丸ごと読むと秘匿値が会話へ残ります。キー名だけなら `grep -o "^[A-Z_]*=" .env` で足ります（no_secret_values_in_output.md）'
fi

# 4b) 秘匿値らしい変数を echo / printf する。
#     二重引用符は展開されるので、ここでは単引用符の中だけを落として見る
#     （`stripped` を使うと `echo "$API_KEY"` が素通りする）。
#     存在確認の `[ -n "$VAR" ]` は値を出さないので、echo / printf に限る。
sq=$(printf '%s' "$nohd" | python3 -c '
import sys, re
print(re.sub(r"\x27[^\x27]*\x27", "", sys.stdin.read()))')

if printf '%s' "$sq" | grep -qE '(^|[[:space:]|;&(])(echo|printf|print)[[:space:]][^|;&]*\$\{?[A-Za-z_]*'"$SECRET"; then
  deny '秘匿値らしい変数を出力しています。存在確認に値は要りません。`[ -n "$VAR" ] && echo set || echo unset` で足ります。`${VAR:-未設定}` も設定済みなら実値が出ます（no_secret_values_in_output.md）'
fi

# 4c) 秘匿値が並んでいる置き場を読む。実際に漏れたのはここからで、
#     `.env` ではなくシェル履歴の列を抜いた経路だった。
#     存在確認は `ls` / `test` で足りるので、読む側だけを止める。
STORES='(\.zsh_history|\.bash_history|\.zhistory|/\.secrets/|/\.aws/credentials|/\.ssh/id_|\.netrc|\.pem)'
if printf '%s' "$sq" | grep -qE '(^|[[:space:]|;&(])(cat|bat|less|more|head|tail|awk|sed|cut|grep|rg|sort|uniq|tr|open|strings)[^|;&]*'"$STORES"; then
  deny '秘匿値が並んでいる置き場を読もうとしています。ここから列を抜いて会話へ出した実例があります。存在確認なら `ls` / `test -f` で足ります。中身の加工がどうしても要るなら、パスを直接書かないスクリプトへ切り出し、**値を出力しない形**で行ってください（no_secret_values_in_output.md）'
fi

# 5) 是非の表明を GitHub へ書く — 承認するのはユーザー本人で、こちらは
#    判断材料と見立てを渡すところまで（review-pr スキル）。条件が無いので
#    形で弾ける（「明示指示があったか」のような会話の状態は見られない）。
if printf '%s' "$sq" | grep -qE 'gh[[:space:]]+pr[[:space:]]+review[^|;&]*(--approve|--request-changes|[[:space:]]-a([[:space:]]|$))'; then
  deny 'PR の承認 / 変更要求はユーザー本人が行います。レビューを投稿するなら `--comment`（API なら `"event":"COMMENT"`）で、是非の表明は会話でユーザーへ渡してください（review-pr スキル「承認は GitHub に書かず、見立てはユーザーへ渡す」）'
fi

exit 0
