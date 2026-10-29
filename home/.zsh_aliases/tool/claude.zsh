# Claude Code
# 追加設定は関数で渡す。エイリアスにフラグを直接書くと、ファイルが無い環境で
# 起動そのものが失敗する。
cld() {
  local extra=~/.claude/settings.private.json
  if [ -f "$extra" ]; then
    claude --settings "$extra" "$@"
  else
    claude "$@"
  fi
}
alias cldr='cld -r'
alias cldw='cld --worktree'
alias cldrc='claude remote-control'

# Anthropic Computer Use
alias computeruse='echo "最後に表示される案内文がどうであれ、http://localhost:8050 でホストされることに注意してください。" \
    && with-secrets docker run \
    -e ANTHROPIC_API_KEY \
    -v $HOME/.anthropic:/home/computeruse/.anthropic \
    -p 5900:5900 \
    -p 8501:8501 \
    -p 6080:6080 \
    -p 8050:8080 \
    -it ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest'
