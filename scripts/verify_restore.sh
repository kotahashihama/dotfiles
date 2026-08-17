#!/bin/sh
#
# バックアップ → リストアを偽の HOME で通しで流し、新規マシンで成立するかを実測する。
#
#   ./scripts/verify_restore.sh
#
# 実リポジトリに対しては読み取りとステージ操作しか行わない。
# コミット・reset --hard は使わない（未コミットの作業を壊すため）。
#
set -u

D=$(cd "$(dirname "$0")/.." && pwd)
W=${VERIFY_WORKDIR:-$(mktemp -d /tmp/dotfiles-verify.XXXXXX)}
PASS=0; FAIL=0
PP=verify-only-passphrase

ok()   { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
ng()   { FAIL=$((FAIL+1)); printf '  ✗ %s — %s\n' "$1" "$2"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else ng "$1" "期待 [$3] 実際 [$2]"; fi; }

setup() {
  rm -rf "$W/repo" "$W/fakehome" "$W/bin"
  mkdir -p "$W/fakehome/Desktop" "$W/bin"
  rsync -a --exclude '.git' --exclude '*.sock' --exclude 'agent/' --exclude 'sockets/' "$D/" "$W/repo/" 2>/dev/null
  printf '#!/bin/sh\necho "[stub] brew $*" >/dev/null\n' > "$W/bin/brew"; chmod +x "$W/bin/brew"
}
backup() { (cd "$W/repo" && PRIVATE_ARCHIVE="$W/priv.tar.gz.gpg" PRIVATE_PASSPHRASE=$PP DOTFILES_DIR="$W/repo" sh scripts/backup_dotfiles.sh >/dev/null 2>&1); }
restore(){ (cd "$W/repo" && PATH="$W/bin:$PATH" HOME="$W/fakehome" DOTFILES_DIR="$W/repo" PRIVATE_ARCHIVE="$W/priv.tar.gz.gpg" PRIVATE_PASSPHRASE=$PP sh scripts/restore_dotfiles.sh >"$W/out.log" 2>&1); echo $?; }
lnk()    { readlink "$W/fakehome/$1" 2>/dev/null | sed "s|$W/repo/||"; }
inarc()  { PRIVATE_PASSPHRASE=$PP sh -c ". $D/scripts/lib.sh; gpg_decrypt $W/priv.tar.gz.gpg" 2>/dev/null | tar tzf - 2>/dev/null; }

SKILLS=$(( $(ls -A "$D/home/.claude/skills" | wc -l) + $(ls -A "$D/private/.claude/skills" 2>/dev/null | wc -l) ))

echo "── 1. スクリプトの構文 ──"
for f in "$D"/scripts/*.sh "$D"/scripts/git-hooks/pre-commit; do
  if sh -n "$f" 2>/dev/null; then ok "$(basename "$f")"; else ng "$(basename "$f")" "構文エラー"; fi
done

echo "── 2. 新規マシンへのリストア ──"
setup; backup; rm -rf "$W/repo/private"
check "終了コード" "$(restore)" "0"
check ".zshrc のリンク先"               "$(lnk .zshrc)"               "home/.zshrc"
check ".zsh_aliases のリンク先"         "$(lnk .zsh_aliases)"         "home/.zsh_aliases"
check ".zsh_aliases_private のリンク先" "$(lnk .zsh_aliases_private)" "private/.zsh_aliases_private"
check ".aws のリンク先"                 "$(lnk .aws)"                 "private/.aws"
check ".secrets のリンク先"             "$(lnk .secrets)"             "private/.secrets"
check "~/.claude/skills 件数"           "$(ls -A "$W/fakehome/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$SKILLS"
check "~/.codex 子要素リンク"           "$(lnk .codex/config.toml)"   "private/.codex/config.toml"
check "deny-patterns は非リンク"        "$([ -e "$W/fakehome/.claude/deny-patterns.txt" ] && echo あり || echo なし)" "なし"
check "秘匿値がアーカイブから復元"      "$([ -f "$W/fakehome/.secrets/env" ] && echo あり || echo なし)" "あり"
check "秘匿値の権限"                    "$(ls -l "$W/fakehome/.secrets/env" 2>/dev/null | cut -c1-10)" "-rw-------"
check "リポジトリ実体 (home)"           "$(cat "$W/repo/home/.zshrc" >/dev/null 2>&1 && echo 無傷 || echo 破損)" "無傷"
check "リポジトリ実体 (private)"        "$(cat "$W/repo/private/.zsh_aliases_private/project.zsh" >/dev/null 2>&1 && echo 無傷 || echo 破損)" "無傷"
check "メモリが projects 配下へ復元"    "$(ls -A "$W/fakehome/.claude/projects" 2>/dev/null | wc -l | tr -d ' ' | awk '{print ($1>0)?"あり":"なし"}')" "あり"
check "メモリが ~ 直下に張られない"     "$([ -e "$W/fakehome/.claude-memory" ] && echo あり || echo なし)" "なし"
# 実体で残ってよいのは PARTIAL_DIRS のトップレベル（子を個別にリンクするため）と、
# Desktop・gpg が作る .gnupg だけ。固定リストにすると PARTIAL_DIRS を増やすたびに偽の失敗が出る。
expected_real=$( { . "$D/scripts/lib.sh"; printf '%s\n' "$PARTIAL_DIRS"; } | cut -d/ -f1 | sort -u; printf 'Desktop\n.gnupg\n.secrets\n' )
unexpected=$(find "$W/fakehome" -maxdepth 1 -type d ! -path "$W/fakehome" -exec basename {} \; | sort | comm -23 - <(printf '%s\n' "$expected_real" | sort -u))
check "~ 直下に想定外の実体が無い"      "$(printf '%s' "$unexpected" | grep -c . | tr -d ' ')" "0"

echo "── 3. シェルの起動 ──"
check "エイリアスが引ける" "$(HOME="$W/fakehome" zsh -ic 'source ~/.zsh_aliases/main.zsh; for a in cldpr cldar ssml gst dcu; do alias $a >/dev/null 2>&1 || echo NG; done' 2>/dev/null | grep -c NG)" "0"
check "秘匿値が空でも起動" "$(HOME="$W/fakehome" zsh -ic 'echo OK' 2>/dev/null | grep -c OK)" "1"

echo "── 4. 冪等性（2 回目のリストア） ──"
check "2 回目の終了コード"         "$(restore)" "0"
check "2 回目もリンク先が正しい"   "$(lnk .zsh_aliases)" "home/.zsh_aliases"
check "2 回目に退避が発生しない"   "$(ls -d "$W/fakehome"/dotfiles-salvaged-* 2>/dev/null | wc -l | tr -d ' ')" "0"
check "2 回目も skills 件数が同じ" "$(ls -A "$W/fakehome/.claude/skills" | wc -l | tr -d ' ')" "$SKILLS"

echo "── 5. 既存の実体がある ~ への上書き ──"
setup; backup; rm -rf "$W/repo/private"
mkdir -p "$W/fakehome/.aws" && echo "既存の実体" > "$W/fakehome/.aws/credentials"
echo "既存の zshrc" > "$W/fakehome/.zshrc"
check "終了コード"               "$(restore)" "0"
check "既存実体が退避された"     "$(ls -d "$W/fakehome"/dotfiles-salvaged-* 2>/dev/null | wc -l | tr -d ' ')" "1"
check "退避後にリンクが張られた" "$(lnk .aws)" "private/.aws"
check "既存 .zshrc も退避された" "$(cat "$W/fakehome"/dotfiles-salvaged-*/.zshrc 2>/dev/null)" "既存の zshrc"

echo "── 6. アーカイブが無い場合（public のみ） ──"
setup; rm -rf "$W/repo/private" "$W/priv.tar.gz.gpg"
check "終了コード"              "$(restore)" "0"
check "警告が出る"              "$(grep -c '見つかりません' "$W/out.log")" "1"
check "public 層はリンクされる" "$(lnk .zshrc)" "home/.zshrc"
check "private 由来は張られない" "$([ -e "$W/fakehome/.aws" ] && echo あり || echo なし)" "なし"
check "秘匿値の雛形が置かれる"  "$([ -f "$W/fakehome/.secrets/env" ] && echo あり || echo なし)" "あり"

echo "── 7. バックアップの中身 ──"
setup; backup
check "アーカイブが作られる"     "$([ -f "$W/priv.tar.gz.gpg" ] && echo あり || echo なし)" "あり"
check "AES-256 で暗号化"         "$(file -b "$W/priv.tar.gz.gpg" | grep -c 'AES with 256-bit')" "1"
check "トップレベルは private"   "$(inarc | cut -d/ -f1 | sort -u | tr '\n' ' ' | sed 's/ $//')" "private"
check "ソケットが除外される"     "$(inarc | grep -c 'ssh/agent/')" "0"
check "秘匿値が含まれる"         "$(inarc | grep -c 'private/.secrets/env')" "1"
check "macOS 設定が含まれる"     "$(inarc | grep -c 'macos-defaults/.*plist' | awk '{print ($1>0)?"あり":"なし"}')" "あり"

echo "── 8. pre-commit フック ──"
cd "$D"
# フックはステージ済みの全ファイルを見る。実行前から何かがステージされていると
# その内容で判定が変わり、この節の結果が信用できなくなる。
if [ -n "$(git diff --cached --name-only)" ]; then
  ng "ステージが空であること" "先にステージ済みのファイルがある。git reset してから再実行する"
fi
hook() {
  git add "$1" 2>/dev/null
  sh scripts/git-hooks/pre-commit >"$W/hooklog" 2>&1; rc=$?
  git reset -q -- "$1" 2>/dev/null; rm -f "$1"
  echo $rc
}
# ダミーの資格情報。リテラルで置くと、このファイル自身がフックに引っかかる
printf 'AKIA%s\n' '1234567890ABCDEF' > home/.claude/rules/__v1.md
check "認証情報でブロック" "$(hook home/.claude/rules/__v1.md)" "1"
printf '# 普通の内容\n' > home/.claude/rules/__v3.md
check "正常なものは通す"   "$(hook home/.claude/rules/__v3.md)" "0"

echo "── 9. 整合性 ──"
check "秘匿値の雛形が実体と一致" "$(diff <(grep -oE '^export [A-Z_]+' "$D/private/.secrets/env" | sort) <(grep -oE '^export [A-Z_]+' "$D/scripts/secrets.env.example" | sort) >/dev/null && echo 一致 || echo 不一致)" "一致"
check "public/private で名前衝突なし" "$(comm -12 <(ls -A "$D/home" | sort) <(ls -A "$D/private" | sort) | grep -v '^.claude$' | wc -l | tr -d ' ')" "0"
check "追跡ファイルに private なし" "$(git -C "$D" ls-files | grep -c '^private/')" "0"

rm -rf "$W"
echo
echo "══ 合計: 成功 $PASS / 失敗 $FAIL ══"
[ "$FAIL" -eq 0 ]
