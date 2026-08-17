# 全プロジェクト共通の前提

## ユーザーについて

**フルスタックエンジニア。強みはフロントエンド。** バックエンド / インフラも担当範囲だが、説明の粒度はそちらに合わせる（`rules/plain_language_explanation.md`）。

日本語で応答する。技術用語とコード識別子は原語のまま。

## 呼称

| 略称 | 正式名 |
| --- | --- |
| **CC** | Claude Code |
| **DD** | Design Doc |

ユーザーがこの略称で書いてくるので、**こちらも同じ略称で返す**。初出でも展開しない。

@~/.claude/CLAUDE.private.md

## 資産の置き分け

| 置き場 | 役割 | いつ読まれるか |
| --- | --- | --- |
| `rules/*.md` | 振る舞いの規約。コミット・レビュー・報告の仕方 | **毎セッション全文** |
| `skills/<name>/SKILL.md` | 手順書。複数ステップの作業 | 呼ばれたときだけ |
| `settings.json` の `hooks` | ツール実行に反応する自動処理 | 該当ツールの実行時 |
| `agents/*.md` | 独自のサブエージェント定義 | 起動したときだけ |
| `output-styles/*.md` | 応答の役割・トーン・形式 | セッション開始時 |
| `projects/<project>/memory/` | **リポジトリ固有の事実**。自分が書く学習ノート | `MEMORY.md` の索引が毎セッション |

**常に効かせたいものは rules、呼ばれたときだけ効かせたいものは skills。** 書き方と整理の規約は `rules/rule_conventions.md` と `rules/align_skill_md_format.md`。

**汎用の規約は rules、そのリポジトリだけの事実は memory。** どちらも毎セッション読まれるので、同じことを書くと二重にロードされる（`rules/rule_conventions.md` の「auto memory との境界」）。

### 公開区分と非公開区分

これらの実体は dotfiles リポジトリにあり、**`home/` 区分は GitHub 上で全世界から読める**。

| 置く内容 | 層 |
| --- | --- |
| 汎用の規約・手順 | `home/`（公開） |
| **社内の呼称・リポジトリ名・GitHub ID・プロダクトの状況** | **`private/`（非公開）** |

**迷ったら `private/` に倒す。** 公開してしまうと取り消せない（履歴の書き換えが要る）。判断表は dotfiles の `docs/placement.md`、点検は同リポジトリの `/audit-secrets` スキル。

**auto memory も dotfiles 管理下**（`private/.claude-memory/<project>/` の実体へシンボリックリンク）。リポジトリ固有の事情を書く場所なので、公開区分には置かない。スキルは**1 本ずつ区分が違う**ので、編集前にリンク先を確かめる。

**編集した時点で dotfiles の作業ツリーが汚れる。** コミットは dotfiles 側の担当セッションへ依頼する（`rules/notify_related_repo_sessions.md`）。

`commands/*.md` は skills に統合済み。既存ファイルは動き続けるが、**新規はすべて skills に置く**。

## 迷ったとき

- 断定の前に一次情報で裏を取る（`rules/verify_before_asserting.md`）
- 結論を先に、全体は簡潔に（`rules/concise_first_then_detail.md`）
- コミット・push・PR の ready 化は明示指示があるときだけ（`rules/no_auto_commit.md`、`rules/no_auto_ready_pr.md`）
