# GitHub に private のリポジトリを作り、ghq の置き場へ SSH で取ってくる
function create-project() {
  local owner=$(gh api user -q .login) || return
  gh repo create "$1" --private && ghq get -p "$owner/$1"
}

# GitHub のリポジトリと、手元の作業ツリーを消す
function delete-project() {
  local owner=$(gh api user -q .login) || return
  # 名前の部分一致で探すと、名前を含む別のリポジトリまで消える
  local dir=$(ghq list --full-path --exact "$owner/$1")

  print -n "本当にリポジトリを削除してよろしいですか？ (Y/n) "
  local confirm
  read -r confirm

  if [[ -z $confirm || $confirm == [Yy] ]]; then
    gh repo delete "$owner/$1" --yes || return
    [[ -n $dir ]] && command rm -rf -- "$dir"
    print "Repository deleted successfully"
  else
    print "Deletion cancelled"
  fi
}
