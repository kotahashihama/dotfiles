# Claude Code のアカウント切り替え（claude-swap）
#
# 基本は会社支給のアカウントで、上限の手前で個人へ移り、枠が空いたら戻る。
# 手で切り替えたときは残量に関わらずそのアカウントを使い続ける。
# その判定は LaunchAgent から ~/.claude/scripts/keep-base-account.sh が回している。
#
# アカウントは cswap 側の別名で指す（cswap alias で設定済み）。ここに
# メールアドレスを書かずに済む
alias cs='cswap'
alias csl='cswap list'
alias css='cswap status'
alias csw='cswap switch work'          # 会社支給へ（固定を解く）
alias csp='cswap switch personal'      # 個人へ（残量に関わらず固定される）
alias cst='cswap tui'                  # 使用量のダッシュボード
alias csa='cswap auto'                 # 手で回すとき（常駐と二重にしない）

# 常駐の操作。gui/<uid> の uid を毎回打つと間違えるので畳む
CSWAP_AGENT=com.kotahashihama.cswap-keep-base
# 登録済みのものを bootstrap すると launchd が Input/output error を返すので、先に外す
alias csup="launchctl bootout gui/\$(id -u)/\$CSWAP_AGENT 2>/dev/null; launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/\$CSWAP_AGENT.plist"
alias csdown="launchctl bootout gui/\$(id -u)/\$CSWAP_AGENT"
alias csinfo="launchctl print gui/\$(id -u)/\$CSWAP_AGENT | head -20"
alias cslog='tail -20 /tmp/cswap-keep-base.log'
alias cserr='tail -20 /tmp/cswap-keep-base.err'
# 判定を1回だけ手で回す。あわせて LaunchAgent が実行するコピーへ同期する。
# launchd は ~/Documents を読めない（TCC）ので、実体へのリンクを実行させられない。
# 実行用は実ファイルのコピーになり、手で回すこの経路で揃える
alias csnow='\cp -f ~/.claude/scripts/keep-base-account.sh "$HOME/Library/Application Support/cswap-keep-base/keep-base-account.sh" && ~/.claude/scripts/keep-base-account.sh'
