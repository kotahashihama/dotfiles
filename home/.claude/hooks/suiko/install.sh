#!/bin/bash
#
# suiko のバイナリを取得する。版と sha256 は同じディレクトリに固定してある。
#
# 辞書を埋め込んでいるので81MBあり、git では運べない。lockfile から
# npm ci で揃える textlint と同じ形で、復元時にここから取る。
#
set -eu

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ver=$(cat "$dir/version")
arch=$(uname -m)
case "$arch" in
  arm64|aarch64) target=aarch64-apple-darwin ;;
  x86_64)        target=x86_64-apple-darwin ;;
  *) echo "suiko: $arch 向けの資産がありません" >&2; exit 1 ;;
esac

tar="suiko-v${ver}-${target}.tar.gz"
url="https://github.com/nwiizo/suiko/releases/download/v${ver}/${tar}"
want=$(awk -v f="$tar" '$2 == f { print $1 }' "$dir/sha256")
[ -n "$want" ] || { echo "suiko: $tar の sha256 が未登録です" >&2; exit 1; }

if [ -x "$dir/bin/suiko" ] && "$dir/bin/suiko" --version 2>/dev/null | grep -q "$ver"; then
  exit 0                       # 同じ版が入っている
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fsSL -o "$work/$tar" "$url"

# 取得できたことと中身が正しいことは別。sha256 が合うまで展開しない
got=$(shasum -a 256 "$work/$tar" | cut -d' ' -f1)
[ "$want" = "$got" ] || { echo "suiko: sha256 が一致しません（$got）" >&2; exit 1; }

tar xzf "$work/$tar" -C "$work"
mkdir -p "$dir/bin"
find "$work" -name suiko -type f -perm +111 -exec cp {} "$dir/bin/suiko" \;
[ -x "$dir/bin/suiko" ] || { echo "suiko: バイナリが取り出せません" >&2; exit 1; }
"$dir/bin/suiko" --version
