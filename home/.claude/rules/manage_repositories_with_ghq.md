# リポジトリは ghq の配置で作り、取ってくる

新しく作るリポジトリも、手元へ取ってくるリポジトリも、ghq のルートの下へ置いてください。
これは全プロジェクト共通の規約です。

```sh
ghq root                                          # 置き場のルート。値は ~/.gitconfig の [ghq] root が決める
ghq create github.com/<owner>/<repo>              # 新しく作る
ghq get github.com/<owner>/<repo>                 # 取ってくる
```

置き場は `$(ghq root)/github.com/<owner>/<repo>` の1通りに決まります。**ルートを直書きしない。** 起点は必ず `$(ghq root)` にする。ルートを変えたときに、直書きした側だけが古い場所を指します。

## GitHub にも作るとき

`ghq create` が作るのは手元だけです。GitHub 側は `gh repo create` で作り、手元のリポジトリを origin へつなぐ。

```sh
cd "$(ghq root)/github.com/<owner>/<repo>"
gh repo create <owner>/<repo> --private --source=. --remote=origin --push
```

公開範囲は取り消せない側の判断なので、作る前にユーザーへ尋ねる（ `decide_or_ask.md` ）。

## 置かないもの

| 置き場 | 扱い |
| --- | --- |
| `~/src`・`~/work`・`/tmp` など、ghq のルートの外 | 使わない。`ghq list` に出ないので、次に探すとき見つからない |
| `git worktree add` の作業ツリー | 対象外。1本のリポジトリから派生した一時の置き場で、ghq が管理するものではない |
| 検証のために使い捨てで取るクローン | セッションのスクラッチパッドへ置き、終わったら消す |

## なぜ

- `ghq list` と、それを使う移動（Ctrl + G）の候補が、手元にあるリポジトリの一覧そのものになる。外へ置くと一覧から漏れる
- 置き場が owner と名前だけで決まるので、どのセッションからでも同じパスで辿れる

## 例外

- ユーザーが置き場を指定した場合

## 関連

- `decide_or_ask.md` （自分で決めるか尋ねるか）: GitHub 上の公開範囲は取り消せない判断なので尋ねる。手元の置き場は本ルールで決まるので尋ねない
