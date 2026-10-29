# エイリアスの入口。種類ごとのファイルを読む
for f in shell lang tool/main tool/docker tool/git tool/claude; do
  . ~/.zsh_aliases/$f.zsh
done
unset f

# 非公開分
[ -f ~/.zsh_aliases_private/main.zsh ] && . ~/.zsh_aliases_private/main.zsh
