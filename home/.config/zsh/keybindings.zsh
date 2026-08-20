#
# キーバインド
#
# 素の emacs キーマップとの差分だけを持つ。Prezto が入れていたものを
# 機械的に抽出したので、移行前と同じ挙動になる。
# Prezto 固有のウィジェットに依存していた 4 件は落とした（expand-or-complete-with-indicator / glob-alias / pound-toggle / prepend-sudo）。
#

bindkey -e

bindkey " " magic-space
bindkey "^S" history-incremental-pattern-search-forward
bindkey "^X?" _complete_debug
bindkey "^XC" _correct_filename
bindkey "^X^B" vi-find-prev-char
bindkey "^X^E" edit-command-line
bindkey "^X^R" _read_comp
bindkey "^X^]" vi-match-bracket
bindkey "^Xa" _expand_alias
bindkey "^Xc" _correct_word
bindkey "^Xd" _list_expansions
bindkey "^Xe" _expand_word
bindkey "^Xh" _complete_help
bindkey "^Xm" _most_recent_file
bindkey "^Xn" _next_tags
bindkey "^Xt" _complete_tag
bindkey "^X~" _bash_list-choices
bindkey "^[," _history-complete-newer
bindkey "^[/" _history-complete-older
bindkey "^[B" emacs-backward-word
bindkey "^[E" expand-cmd-path
bindkey "^[F" emacs-forward-word
bindkey "^[K" backward-kill-line
bindkey "^[M" copy-prev-shell-word
bindkey "^[OF" end-of-line
bindkey "^[OH" beginning-of-line
bindkey "^[Oc" emacs-forward-word
bindkey "^[Od" emacs-backward-word
bindkey "^[Q" push-line-or-edit
bindkey "^[[1;5C" emacs-forward-word
bindkey "^[[1;5D" emacs-backward-word
bindkey "^[[2~" overwrite-mode
bindkey "^[[3~" delete-char
bindkey "^[[5C" emacs-forward-word
bindkey "^[[5D" emacs-backward-word
bindkey "^[[Z" reverse-menu-complete
bindkey "^[^[OC" emacs-forward-word
bindkey "^[^[OD" emacs-backward-word
bindkey "^[^[[C" emacs-forward-word
bindkey "^[^[[D" emacs-backward-word
bindkey "^[_" redo
bindkey "^[b" emacs-backward-word
bindkey "^[e" expand-cmd-path
bindkey "^[f" emacs-forward-word
bindkey "^[k" backward-kill-line
bindkey "^[m" copy-prev-shell-word
bindkey "^[q" push-line-or-edit
bindkey "^[~" _bash_complete-word

# Prezto 固有だったウィジェットのうち、要るものを素の zsh で置き直す

# 行頭に sudo を付ける（^X^S）
prepend-sudo() {
  [[ "$BUFFER" != sudo\ * ]] && BUFFER="sudo $BUFFER" && (( CURSOR += 5 ))
}
zle -N prepend-sudo
bindkey '^X^S' prepend-sudo

# 行頭の # を付け外しして、実行せず履歴へ残す（Esc ;）
pound-toggle() {
  if [[ "$BUFFER" = \#* ]]; then BUFFER="${BUFFER#\#}"; (( CURSOR -= 1 ))
  else BUFFER="#$BUFFER"; (( CURSOR += 1 )); fi
}
zle -N pound-toggle
bindkey '^[;' pound-toggle

# 行を編集用に開く
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# 履歴の部分一致検索。プラグインが読まれたときだけ結び付ける
if (( $+widgets[history-substring-search-up] )); then
  bindkey "^N" history-substring-search-down
  bindkey "^P" history-substring-search-up
  bindkey "^[OA" history-substring-search-up
  bindkey "^[OB" history-substring-search-down
fi
