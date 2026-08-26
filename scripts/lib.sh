#!/bin/sh
#
# backup / restore が共有する定義とヘルパー。
#

# リポジトリの位置。クローン先を選ばないよう、既定は git に訊く。
# lib.sh は必ず `.` で読まれるので $0 は呼び出し元を指す。そこを起点にする。
# DOTFILES_DIR を渡せば上書きできる（検証で偽の場所を指すときに使う）。
if [ -z "${DOTFILES_DIR:-}" ]; then
  # CDPATH が設定されていると cd が別の場所へ飛ぶ。サブシェル内で空にする
  _libdir=$(unset CDPATH; cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
  DOTFILES_DIR=$(git -C "${_libdir:-.}" rev-parse --show-toplevel 2>/dev/null) \
    || DOTFILES_DIR=~/Documents/repositories/github.com/kotahashihama/dotfiles
  unset _libdir
fi
PRIVATE_ARCHIVE=${PRIVATE_ARCHIVE:-~/Desktop/private_dotfiles.tar.gz.gpg}

# 非公開側は SSH 秘密鍵・クラウドの資格情報・API キーを含むため暗号化して運ぶ。
# zip の --encrypt は ZipCrypto で既知の攻撃があるので使わない。
#
# PRIVATE_PASSPHRASE を渡すと非対話で動く。検証やスクリプト用で、
# 手作業では渡さない（ps とシェル履歴に残る）。
gpg_encrypt() {
  if [ -n "${PRIVATE_PASSPHRASE:-}" ]; then
    gpg --batch --yes --quiet --symmetric --cipher-algo AES256 \
        --passphrase "$PRIVATE_PASSPHRASE"
  else
    gpg --symmetric --cipher-algo AES256
  fi
}

gpg_decrypt() {
  if [ -n "${PRIVATE_PASSPHRASE:-}" ]; then
    gpg --batch --yes --quiet --decrypt --passphrase "$PRIVATE_PASSPHRASE" "$1"
  else
    gpg --quiet --decrypt "$1"
  fi
}

# 実体が別の物と同居するため、ディレクトリごとではなく子要素を個別にリンクする対象。
# 例: ~/.claude にはセッションやキャッシュも入るので、丸ごとリンクすると巻き込む。
# 両方が同じディレクトリへ要素を持ち寄る場合も、ここへ入れて衝突を避ける。
PARTIAL_DIRS='.claude
.claude/skills
.config
.codex
.cursor
.openclaw
Library
Library/Application Support
Library/Application Support/Cursor
Library/Application Support/Cursor/User
Library/LaunchAgents'

# 空白を含むパス（Library/Application Support）があるため、行単位で完全一致を見る。
# for d in $PARTIAL_DIRS だと単語分割で壊れる。
is_partial() {
  printf '%s\n' "$PARTIAL_DIRS" | grep -Fxq -- "$1"
}

# 置き場に入れるが、~ 直下へはリンクしないもの。
# deny-patterns.txt はこのリポジトリの道具立てで、~ に置いても意味がない。
# .claude-memory は ~ 直下ではなく ~/.claude/projects/<key>/memory へ張る。
NO_LINK='.claude/deny-patterns.txt
.claude-memory'

is_no_link() {
  printf '%s\n' "$NO_LINK" | grep -Fxq -- "$1"
}

# 何本張ったかを数える。何も報告せずに終わると、効いたのか分からない。
LINKED=0
UNCHANGED=0
SALVAGED=0

# DRY_RUN=1 を渡すと、何が起きるかだけ出して変更しない。
# 37本のリンクを張るので、初回は先に見えたほうがよい。
DRY_RUN=${DRY_RUN:-}

# リンクを張る。既存の実体があれば消さずに退避する。
link_into_home() {
  src=$1   # リポジトリ内の絶対パス
  dst=$2   # ~ 配下の絶対パス

  # 既に同じ先を指していれば触らない。数えるためだけに分岐する
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    UNCHANGED=$((UNCHANGED + 1))
    [ -n "$DRY_RUN" ] && echo "  そのまま: $dst"
    return 0
  fi

  if [ -n "$DRY_RUN" ]; then
    if [ -L "$dst" ]; then
      echo "  張り替え: $dst -> $src"
    elif [ -e "$dst" ]; then
      echo "  退避してから張る: $dst"
    else
      echo "  新規: $dst -> $src"
    fi
    LINKED=$((LINKED + 1))
    return 0
  fi

  if [ -L "$dst" ]; then
    rm -f "$dst"
  elif [ -e "$dst" ]; then
    mkdir -p "$SALVAGE_DIR"
    mv "$dst" "$SALVAGE_DIR/"
    echo "  退避: $dst -> $SALVAGE_DIR/"
    SALVAGED=$((SALVAGED + 1))
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
  LINKED=$((LINKED + 1))
}

# 集計を1行で出す。
report_links() {
  printf '   リンク %s 本 / そのまま %s 本 / 退避 %s 件\n' "$LINKED" "$UNCHANGED" "$SALVAGED"
}

# 1つの置き場 (home / private) を ~ へリンクする。
# PARTIAL_DIRS に該当する要素は掘り下げ、そうでない要素をリンクする。
#
# 再帰は使わない。POSIX sh に局所変数が無く、再帰呼び出しが親のループ変数を
# 上書きするため、掘り下げた後の要素が誤った位置へリンクされる。
link_layer() {
  layer=$1
  layer_base="$DOTFILES_DIR/$layer"
  [ -d "$layer_base" ] || return 0

  queue=$(ls -A "$layer_base")
  while [ -n "$queue" ]; do
    rel=$(printf '%s\n' "$queue" | sed -n '1p')
    queue=$(printf '%s\n' "$queue" | sed -n '2,$p')
    [ -n "$rel" ] || continue

    if is_no_link "$rel"; then
      continue
    elif is_partial "$rel"; then
      mkdir -p ~/"$rel"
      children=$(ls -A "$layer_base/$rel" | sed "s|^|$rel/|")
      queue=$(printf '%s\n%s' "$children" "$queue" | sed '/^$/d')
    else
      link_into_home "$layer_base/$rel" ~/"$rel"
    fi
  done
}

# 書き出した defaults を取り込む。restore_osx.sh から呼ぶが、
# 単体で検証できるようここに置く。
import_macos_defaults() {
  dir=$1
  [ -d "$dir" ] || { echo "   書き出した設定がありません"; return 0; }
  n=0
  for f in "$dir"/*.plist; do
    [ -f "$f" ] || continue
    defaults import "$(basename "$f" .plist)" "$f" && n=$((n + 1))
  done
  echo "   書き出した設定を取り込みました: ${n}ドメイン"
}

# 拡張子とアプリの関連付けを適用する。アプリが未導入なら失敗するが、
# 入れ直せば揃うので中断しない。
apply_associations() {
  file=$1
  [ -f "$file" ] || return 0
  if ! command -v duti >/dev/null 2>&1; then
    echo "   duti が無いため関連付けを飛ばしました。brew install duti の後に流し直してください"
    return 0
  fi
  n=0
  while read -r bundle ext role; do
    [ -n "$bundle" ] || continue
    duti -s "$bundle" "$ext" "$role" 2>/dev/null && n=$((n + 1))
  done < "$file"
  echo "   関連付けを適用しました: $n / $(wc -l < "$file" | tr -d ' ')件"
}
