# 全プロジェクト共通の前提

## ユーザーについて

**フロントエンドを専門とするエンジニア。** バックエンド / インフラは専門外なので、説明の粒度を領域で変える（`rules/plain_language_explanation.md`）。

日本語で応答する。技術用語とコード識別子は原語のまま。

@~/.claude/CLAUDE.private.md

## 資産の置き分け

| 置き場 | 役割 | いつ読まれるか |
| --- | --- | --- |
| `rules/*.md` | 振る舞いの規約。コミット・レビュー・報告の仕方 | **毎セッション全文** |
| `skills/<name>/SKILL.md` | 手順書。複数ステップの作業 | 呼ばれたときだけ |
| `settings.json` の `hooks` | ツール実行に反応する自動処理 | 該当ツールの実行時 |
| `agents/*.md` | 独自のサブエージェント定義 | 起動したときだけ |
| `output-styles/*.md` | 応答の役割・トーン・形式 | セッション開始時 |

**常に効かせたいものは rules、呼ばれたときだけ効かせたいものは skills。** 書き方と整理の規約は `rules/rule_conventions.md` と `rules/align_skill_md_format.md`。

`commands/*.md` は skills に統合済み。既存ファイルは動き続けるが、**新規はすべて skills に置く**。

## 迷ったとき

- 断定の前に一次情報で裏を取る（`rules/verify_before_asserting.md`）
- 結論を先に、全体は簡潔に（`rules/concise_first_then_detail.md`）
- コミット・push・PR の ready 化は明示指示があるときだけ（`rules/no_auto_commit.md`、`rules/no_auto_ready_pr.md`）
