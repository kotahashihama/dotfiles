#
# ツールの初期化
#

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# direnv
eval "$(direnv hook zsh)"

# Docker
source <(docker completion zsh)

# mise
eval "$(/opt/homebrew/bin/mise activate zsh)"

# zoxide
# cd を置き換える。よく行く場所は部分一致で飛べるようになり、
# 明示的なパス指定は今までどおり動く。^q の cdr は履歴順なので役割が違う
eval "$(zoxide init zsh --cmd cd)"

# atuin
# 履歴を SQLite で持ち、ディレクトリ・終了コード・日時で絞り込める。^r を置き換える。
# 上矢印は今までどおり部分一致検索に使いたいので atuin へは渡さない
eval "$(atuin init zsh --disable-up-arrow)"

# carapace
# 多くの CLI の補完をまとめて供給する。zsh-completions と併存できる
export CARAPACE_BRIDGES='zsh,fish,bash'
source <(carapace _carapace zsh)

# Kiro
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# clauth
# 補完ファイルは #compdef 形式なので、source だけでは登録されない（compdef で結ぶ）。
# fpath へ置く手は compinit -C のキャッシュに入るまで効かないので採らない
if [[ -f "$HOME/.clauth/completions/clauth.zsh" ]]; then
  source "$HOME/.clauth/completions/clauth.zsh"
  compdef _clauth clauth
fi

# Vault の点検
# launchd から起動した op は 1Password の承認を受けられないので、手元のシェルで流すよう促す。
# 報告が30日より古いか無ければ1行出す
() { (( $# )) } ~/.local/state/vault-audit/report.md(N.md-30) || print 'Vault の点検から30日経っています: vault-audit --vault all'
