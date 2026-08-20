#!/bin/bash
#
# バックアップ → リストアを偽の HOME で通しで流し、新規マシンで成立するかを実測する。
#
#   ./scripts/verify_restore.sh
#
# 実リポジトリに対しては読み取りとステージ操作しか行わない。
# コミット・reset --hard は使わない（未コミットの作業を壊すため）。
#
# プロセス置換を使うため bash で書く。sh では動かない。
set -u

D=$(cd "$(dirname "$0")/.." && pwd)
W=${VERIFY_WORKDIR:-$(mktemp -d /tmp/dotfiles-verify.XXXXXX)}
PASS=0; FAIL=0
PP=verify-only-passphrase

ok()   { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
ng()   { FAIL=$((FAIL+1)); printf '  ✗ %s — %s\n' "$1" "$2"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else ng "$1" "期待 [$3] 実際 [$2]"; fi; }

setup() {
  rm -rf "${W:?}/repo" "${W:?}/fakehome" "${W:?}/bin"
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
# shellcheck disable=SC2088  # 表示用の文字列。実パスは別途展開している
check "~/.claude/skills 件数"           "$(ls -A "$W/fakehome/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$SKILLS"
# shellcheck disable=SC2088  # 表示用の文字列。実パスは別途展開している
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
check "エイリアスが引ける" "$(HOME="$W/fakehome" zsh -ic 'source ~/.zsh_aliases/main.zsh; for a in cldw ssml gst dcu; do alias $a >/dev/null 2>&1 || echo NG; done; (( $+functions[cld] )) || echo NG' 2>/dev/null | grep -c NG)" "0"
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
check "publicはリンクされる" "$(lnk .zshrc)" "home/.zshrc"
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
check "関連付けが含まれる"       "$(inarc | grep -c 'associations/duti.txt')" "1"
check "テキスト置換が含まれる"   "$(inarc | grep -c 'keyboard/text-replacements.tsv')" "1"
check "インストール一覧が含まれる" "$(inarc | grep -c 'inventory/.*txt' | awk '{print ($1>0)?"あり":"なし"}')" "あり"
check "LaunchAgents が含まれる"  "$(inarc | grep -c 'LaunchAgents/.*plist' | awk '{print ($1>0)?"あり":"なし"}')" "あり"

echo "── 8. pre-commit フック ──"
cd "$D" || exit 1
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
# 分割対象（PARTIAL_DIRS）は両側に同名で存在してよい。中の別々のものを持つため
check "public/private で名前衝突なし" "$(comm -12 <(ls -A "$D/home" | sort) <(ls -A "$D/private" | sort) | grep -vxF "$( . "$D/scripts/lib.sh" >/dev/null 2>&1; printf '%s\n' "$PARTIAL_DIRS" | cut -d/ -f1 | sort -u )" | wc -l | tr -d ' ')" "0"
check "追跡ファイルに private なし" "$(git -C "$D" ls-files | grep -c '^private/')" "0"

echo "── 10. lib.sh の関数 ──"
( . "$D/scripts/lib.sh" >/dev/null 2>&1
  is_partial ".claude"                       && echo P1
  is_partial "Library/Application Support"   && echo P2
  is_partial ".zshrc"                        || echo P3
  is_no_link ".claude-memory"                && echo N1
  is_no_link ".zshrc"                        || echo N2
) > "$W/fn.txt" 2>/dev/null
check "is_partial が一致を拾う"       "$(grep -c P1 "$W/fn.txt")" "1"
check "is_partial が空白入りを拾う"   "$(grep -c P2 "$W/fn.txt")" "1"
check "is_partial が無関係を弾く"     "$(grep -c P3 "$W/fn.txt")" "1"
check "is_no_link が一致を拾う"       "$(grep -c N1 "$W/fn.txt")" "1"
check "is_no_link が無関係を弾く"     "$(grep -c N2 "$W/fn.txt")" "1"

# link_into_home の 3 分岐
LW="$W/lih"; rm -rf "$LW"; mkdir -p "$LW/src" "$LW/home"
echo src > "$LW/src/f"
( . "$D/scripts/lib.sh" >/dev/null 2>&1
  SALVAGE_DIR="$LW/salvage"
  link_into_home "$LW/src/f" "$LW/home/a"                       # 新規
  ln -sfn /nonexistent "$LW/home/b"; link_into_home "$LW/src/f" "$LW/home/b"  # 既存リンク
  echo real > "$LW/home/c";          link_into_home "$LW/src/f" "$LW/home/c"  # 既存の実体
) >/dev/null 2>&1
check "新規にリンクを張る"       "$(readlink "$LW/home/a" | sed "s|.*/||")" "f"
check "既存リンクを張り替える"   "$(readlink "$LW/home/b" | sed "s|.*/||")" "f"
check "既存の実体を退避する"     "$(cat "$LW/salvage/c" 2>/dev/null)" "real"
check "退避後にリンクを張る"     "$(readlink "$LW/home/c" | sed "s|.*/||")" "f"

echo "── 11. 書き出しスクリプト ──"
OW="$W/out"; rm -rf "$OW"; mkdir -p "$OW"
( cd "$D" && DOTFILES_DIR="$OW" sh scripts/backup_osx.sh ) >"$W/osx.log" 2>&1
check "backup_osx が plist を出す"     "$(ls -A "$OW/private/.macos-defaults" 2>/dev/null | grep -c plist | awk '{print ($1>0)?"あり":"なし"}')" "あり"
check "backup_osx が一覧を出す"        "$(ls -A "$OW/private/.inventory" 2>/dev/null | wc -l | tr -d ' ' | awk '{print ($1>0)?"あり":"なし"}')" "あり"
( cd "$D" && DOTFILES_DIR="$OW" sh scripts/backup_associations.sh ) >/dev/null 2>&1
check "backup_associations の出力形式" "$(awk 'NF!=3{bad=1} END{print (bad)?"不正":"3 列"}' "$OW/private/.associations/duti.txt" 2>/dev/null)" "3 列"
( cd "$D" && DOTFILES_DIR="$OW" sh scripts/backup_keyboard.sh ) >/dev/null 2>&1
check "backup_keyboard が出力する"     "$([ -f "$OW/private/.keyboard/text-replacements.tsv" ] && echo あり || echo なし)" "あり"

echo "── 12. 取り込みの関数 ──"
IW="$W/imp"; rm -rf "$IW"; mkdir -p "$IW/defaults"
defaults export com.apple.TextEdit "$IW/defaults/com.apple.TextEdit.plist" 2>/dev/null
check "defaults を取り込む"       "$( ( . "$D/scripts/lib.sh"; import_macos_defaults "$IW/defaults" ) 2>/dev/null | grep -oE '[0-9]+ ドメイン')" "1 ドメイン"
check "書き出しが無ければ飛ばす"  "$( ( . "$D/scripts/lib.sh"; import_macos_defaults "$IW/nothere" ) 2>/dev/null | grep -c 'ありません')" "1"
check "関連付けの入力が無ければ何もしない" "$( ( . "$D/scripts/lib.sh"; apply_associations "$IW/nothere.txt" ) 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "── 13. 異常系 ──"
setup; backup
check "誤ったパスフレーズで復号できない" "$(PRIVATE_PASSPHRASE=wrong sh -c ". $D/scripts/lib.sh; gpg_decrypt $W/priv.tar.gz.gpg" >/dev/null 2>&1 && echo できた || echo できない)" "できない"
printf 'broken' > "$W/broken.gpg"
check "壊れたアーカイブで復号できない" "$(PRIVATE_PASSPHRASE=$PP sh -c ". $D/scripts/lib.sh; gpg_decrypt $W/broken.gpg" >/dev/null 2>&1 && echo できた || echo できない)" "できない"
check "gpg が無ければバックアップが止まる" "$( ( cd "$W/repo" && PATH=/usr/bin:/bin PRIVATE_ARCHIVE=$W/x.gpg DOTFILES_DIR=$W/repo sh scripts/backup_dotfiles.sh ) >/dev/null 2>&1 && echo 続行 || echo 停止)" "停止"

echo "── 14. adopt_dotfile ──"
AW="$W/adopt"; rm -rf "$AW"; mkdir -p "$AW/repo/home" "$AW/repo/private" "$AW/fakehome"
echo hello > "$AW/fakehome/.testrc"
( cd "$AW/repo" && HOME="$AW/fakehome" DOTFILES_DIR="$AW/repo" sh "$D/scripts/adopt_dotfile.sh" private .testrc ) >/dev/null 2>&1
check "private へ移す"       "$(cat "$AW/repo/private/.testrc" 2>/dev/null)" "hello"
check "元の位置がリンクになる" "$([ -L "$AW/fakehome/.testrc" ] && echo リンク || echo 実体)" "リンク"
check "リンク経由で読める"     "$(cat "$AW/fakehome/.testrc" 2>/dev/null)" "hello"

rm -rf "${W:?}"
echo
echo "══ 合計: 成功 $PASS / 失敗 $FAIL ══"
[ "$FAIL" -eq 0 ]
