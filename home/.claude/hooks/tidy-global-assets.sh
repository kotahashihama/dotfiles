#!/bin/bash
# グローバルルール / グローバルスキルを編集したときに、整理を促す。
# PostToolUse (Write|Edit) から呼ばれ、stdin に tool_input を含む JSON を受け取る。
set -u

payload=$(cat)
path=$(printf '%s' "$payload" | python3 -c '
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); raise SystemExit
print(d.get("tool_input", {}).get("file_path", "") or "")
' 2>/dev/null)

[ -z "$path" ] && exit 0

case "$path" in
  "$HOME"/.claude/rules/*.md)
    cat <<'MSG'
グローバルルールを編集しました。rule_conventions.md の「整理の契機」に従い、この編集を契機に棚卸しまで済ませてください。

- 分割: 1 ファイルに主題が 2 つ以上ないか
- マージ: 同じ主題が複数ファイルに散っていないか
- 削除: 無くても挙動が変わらないルール、既定の挙動に取り込まれたルールが無いか

整理が不要と判断した場合も、確認した旨を報告してください。
MSG
    ;;
  "$HOME"/.claude/skills/*/SKILL.md)
    cat <<'MSG'
グローバルスキルを編集しました。この編集を契機に、スキル全体の棚卸しまで済ませてください。

- 分割: 1 スキルが複数の責務を抱えていないか
- マージ: 同じ手順が複数スキルに重複していないか（委譲で解けないか）
- 削除: 他スキルで代替でき呼ばれなくなったものが無いか（既定に取り込まれた例は稀。あれば消す）
- 整合: 委譲先スキルの手順を自前で再定義していないか、相互参照が実態と合っているか

整理が不要と判断した場合も、確認した旨を報告してください。
MSG
    ;;
  "$HOME"/.claude/CLAUDE.md)
    cat <<'MSG'
グローバルの CLAUDE.md を編集しました。この編集を契機に、グローバル資産の置き分けを見直してください。

- 重複: rules/ に同じことが書かれていないか（CLAUDE.md は前提、rules は規約）
- 移動: 常に効かせたい規約なら rules/ へ、手順なら skills/ へ
- 参照: 本文が指すルール・スキルが実在するか

整理が不要と判断した場合も、確認した旨を報告してください。
MSG
    ;;
  "$HOME"/.claude/settings.json|*/dotfiles/home/.claude/settings.json)
    cat <<'MSG'
グローバル settings.json を編集しました。この編集を契機に、設定とフックを見直してください。

- hooks: 参照先スクリプトが実在し実行可能か。発火条件が広すぎないか
- 重複: rules/ に「毎回やる」と書いてある処理を、hooks へ寄せられないか
- 不要: 既定の挙動に取り込まれた設定・使われていないフックが無いか

整理が不要と判断した場合も、確認した旨を報告してください。
MSG
    ;;
  *)
    exit 0
    ;;
esac
