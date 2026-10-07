---
paths:
  - "**/AGENTS.md"
  - "**/CLAUDE.md"
  - "**/.claude/rules/**"
  - "**/.claude/skills/**"
  - "**/.agents/**"
---

# エージェントの設定は Claude Code に置き、ほかのエージェントへはリンクで渡す

指示・ルール・スキルの実体は Claude Code が読む場所に置き、Codex などのほかのエージェントには、シンボリックリンクで同じ実体を渡してください。
これは全プロジェクト共通の規約です。

**実体を2か所に持たない。** 写しを置くと片方だけ直されて食い違い、どちらが正しいか決められなくなります。

## 置き場

リポジトリでは次の形にします。

| 種類 | 実体 | リンク |
| --- | --- | --- |
| 指示 | `AGENTS.md` | `CLAUDE.md` → `AGENTS.md` （同じディレクトリ） |
| ルール | `.claude/rules/<主題>.md` | `.agents/rules/<主題>.md` → `../../.claude/rules/<主題>.md` |
| スキル | `.claude/skills/<名前>/` | `.agents/skills/<名前>` → `../../.claude/skills/<名前>` |

グローバル（dotfiles の `home/` ）では、ユーザー単位の置き場が次のとおりです。ルールは Codex が読まないので `.agents/rules` は作らず、`AGENTS.md` から `~/.claude/rules/` を指します。

| 読む側 | 読む場所 | 置くもの |
| --- | --- | --- |
| Claude Code | `~/.claude/CLAUDE.md` | `AGENTS.md` へのリンク |
| Codex | `~/.codex/AGENTS.md`・`~/.agents/skills/` | `AGENTS.md` へのリンク・各スキルへのリンク |

編集するのは実体だけです。リンクの側には中身を書きません。

```bash
ln -s AGENTS.md CLAUDE.md
ln -s ../../.claude/rules/<主題>.md .agents/rules/<主題>.md
ln -s ../../.claude/skills/<名前> .agents/skills/<名前>
```

**リンクの向きは、指示とそれ以外で逆になる。** ルールとスキルは Claude Code の側（ `.claude/` ）が実体で、ほかのエージェントの側（ `.agents/` ）がリンクです。指示だけは、ほかのエージェントと共通の名前（ `AGENTS.md` ）が実体で、`CLAUDE.md` がリンクです。

指示を逆向きにするのは、Claude Code の読み方のためです。Claude Code は `AGENTS.md` を、同じ階層とその上に `CLAUDE.md` が無いときだけ読み、ユーザー単位の `AGENTS.md` の置き場もありません。`CLAUDE.md` を `AGENTS.md` へのリンクにすれば、どこで開いても1回だけ読まれます。公式ドキュメントも、リンクにした `CLAUDE.md` は中身が1回だけ読まれると案内しています。

## ほかのエージェントが読まないもの

| 仕組み | Claude Code | Codex | 埋め方 |
| --- | --- | --- | --- |
| `.claude/rules/` | 読む | 読まない。Markdown のルールのフォルダを読む仕組みが無い | `AGENTS.md` に「ルールを開いて従う」と書く |
| `paths` での読み込み | 効く | 効かない | 同上。作業に関わるルールを自分で開いてもらう |
| `@path` での読み込み | 効く | 記載が無い | `@` に「読んでから従う」の文を添える |

**Codex の「Rules」は、同じ名前の別の機能です。** `~/.codex/rules/` と `<repo>/.codex/rules/` に置く Starlark の `.rules` ファイルで、Codex がサンドボックスの外で実行してよいコマンドを決めます。振る舞いの規約を書く場所ではないので、Markdown のルールやそのリンクを `.codex/rules/` に置かない。

Markdown のルールを Codex でも `paths` 付きで読めるようにする要望は出ています（openai/codex#34002、まだ open）。ツールをまたぐ置き場として `.agents/rules/` を標準にする提案もあり、`.agents/rules/` にリンクを置くのはこれを見越した揃えです。今の Codex の挙動は変えません。

**Claude Code での効き目を落とさない。** `@` をやめて普通のパスにすると、Claude Code は中身を読み込まなくなります。Claude Code の書き方を残し、ほかのエージェントが読んで通じなさそうなら説明を添える。

## 足したら、リンクも足す

ルールやスキルを新しく作ったら、同じ作業の中で `.agents/` にリンクを足します。グローバルのスキルは、dotfiles の `scripts/link_agents_skills.sh` が `~/.claude/skills/` の全部へリンクを張ります。

消したときも同じです。実体の無いリンクを残すと、Codex が読めないスキルを一覧に出します。

## 禁止する挙動

- 指示・ルール・スキルの写しを、エージェントごとに置くこと。片方だけ直されて食い違う
- `.agents/` のリンクの側を編集すること。実体を直す
- `CLAUDE.md` に中身を書くこと。`AGENTS.md` を実体にし、`CLAUDE.md` はリンクにする
- ほかのエージェントに合わせて、`@` での読み込みをやめること。Claude Code が読み込まなくなる
- ルールやスキルを足して、`.agents/` のリンクを足さないこと
- Markdown のルールやそのリンクを `.codex/rules/` に置くこと。そこはコマンドの実行の可否を決める `.rules` ファイルの置き場

## なぜ

- 同じ規約を2つのエージェントで使うなら、実体は1つでないと必ず食い違う
- Claude Code を基準にしているので、実体は Claude Code の読む場所に置く。ほかのエージェントはリンクを辿れる
- Claude Code と Codex は読み込む場所と仕組みが違う。差を書いておかないと、片方でだけ効かない規約が増える

## 例外

- そのエージェントにしか意味の無い設定（ `settings.json`・`config.toml` ）は、それぞれの場所に置く

## 関連

- `rule_conventions.md` （ルールとスキルの置き分け）: ルールかスキルかの判定はあちら。本ルールは、決めた実体をほかのエージェントへどう渡すか
- `no_internal_names_in_public_assets.md` （公開側に社内固有名を書かない）: `home/` に置くリンクと実体も公開される。リンクは相対パスで張り、ユーザー名の入った絶対パスを書かない
