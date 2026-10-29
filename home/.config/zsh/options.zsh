#
# zsh のオプション
#
# Prezto の environment / history / directory / completion / editor / utility から
# 抜き出したもの。フレームワークを外したので、効いていた設定を明示的に持つ。
#

# 環境
setopt COMBINING_CHARS       # 濁点などの結合文字を 1 文字として扱う
setopt INTERACTIVE_COMMENTS  # 対話シェルでも # 以降をコメントにする
setopt RC_QUOTES             # '' で ' を表せる
setopt LONG_LIST_JOBS        # jobs を長い形式で出す
setopt AUTO_RESUME           # 同名のジョブがあれば再開する
setopt NOTIFY                # バックグラウンドジョブの終了を即座に知らせる
unsetopt MAIL_WARNING
unsetopt BG_NICE             # バックグラウンドジョブの優先度を下げない
unsetopt HUP                 # シェル終了時にジョブを殺さない
unsetopt CHECK_JOBS          # 終了時にジョブの確認をしない

# 履歴
# 保存は別のファイルに書いてから差し替えるので、リンクのまま渡すとリンクが実体に置き換わる
# リンクを解決した先を渡す
HISTFILE="${${:-$HOME/.zsh_history}:A}"
HISTSIZE=10000
SAVEHIST=10000
setopt BANG_HIST
setopt EXTENDED_HISTORY       # 実行時刻と所要時間も記録する
setopt SHARE_HISTORY          # 複数のシェルで履歴を共有する
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE      # 空白で始めた行は記録しない
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY            # 履歴展開を即実行せず、一度表示する
setopt HIST_BEEP

# ディレクトリ
setopt AUTO_CD               # パスだけ打つと cd する
setopt AUTO_PUSHD            # cd でスタックに積む
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt PUSHD_TO_HOME
setopt CDABLE_VARS
setopt MULTIOS
setopt PROMPT_SUBST          # プロンプト内で変数と \$(...) を展開する。Powerlevel10k が要求する
setopt EXTENDED_GLOB
setopt MAGIC_EQUAL_SUBST     # --opt=~/path の = の後ろも展開する
unsetopt CLOBBER             # > で既存ファイルを上書きしない。上書きは >| で行う

# 補完
setopt COMPLETE_IN_WORD      # 単語の途中からでも補完する
setopt ALWAYS_TO_END         # 補完後にカーソルを末尾へ
setopt PATH_DIRS             # スラッシュを含むコマンド名もパス探索する
unsetopt AUTO_MENU           # Tab の2回目で候補を順に選ばない。候補の選択は fzf-tab が受け持つ
setopt AUTO_LIST
setopt AUTO_PARAM_SLASH
unsetopt MENU_COMPLETE       # 先頭候補を自動選択しない
unsetopt FLOW_CONTROL        # ^S / ^Q を端末制御に取られない
unsetopt CASE_GLOB           # グロブを大文字小文字を区別せず照合する

# その他
setopt BEEP
setopt CORRECT               # コマンド名の打ち間違いを指摘する
unsetopt CORRECT_ALL         # 引数までは指摘しない
