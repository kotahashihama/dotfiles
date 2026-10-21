# 全プロジェクト共通の前提

## ユーザーについて

**フルスタックエンジニア。強みはフロントエンド。** バックエンド / インフラも担当範囲だが、説明の粒度はそちらに合わせる（ `rules/plain_language_explanation.md` ）。

日本語で応答する。技術用語とコード識別子は原語のまま。**会話は敬語（ですます調）で書く。** 英語で書かれたプラグインのスキル（pstack・mattpocock-skills など）を使うときも、応答は日本語で書く。スキルの手順や出力の雛形が英語でも、ユーザーへ返す文章は日本語に直す。

## 呼称

| 略称 | 正式名 |
| --- | --- |
| **CC** | Claude Code |
| **DD** | Design Doc |

ユーザーがこの略称で書いてくるので、**こちらも同じ略称で返す**。初出でも展開しない。

非公開の前提（氏名・所属・扱うリポジトリ）は、非公開側のルール `~/.claude/rules/user_context.md` が持つ。

## Claude Code 以外のエージェントへ

この指示は Claude Code を基準に書いている。ルールの実体は `~/.claude/rules/*.md` にあり、Claude Code は自動で読み込むが、ほかのエージェントは読み込まない。**作業を始める前に、作業に関わるルールを開いて従う。** 先頭に `paths` があるルールは、それに合うファイルを扱うときだけ従えばよい。スキルは `~/.agents/skills/` から使える（実体は `~/.claude/skills/` ）。

ルールとスキルには Claude Code の仕組みの名前が出てくる。手元に同じものが無ければ、次のように読み替える。

| 書いてあるもの | 意味 | 無いときの代わり |
| --- | --- | --- |
| `Read`・`Write`・`Edit`・`Glob`・`Grep`・`Bash` などのツール名 | ファイルを読む・書く・探す道具と、コマンドを実行する道具 | 手元の同じ役目の道具を使う |
| `AskUserQuestion` | 選択肢を出してユーザーに尋ねるツール | 問いと選択肢を番号付きで文に並べ、推奨を先頭に置いて尋ねる |
| `SendMessage`・`ListAgents` | ほかのセッションへの連絡と、その一覧 | 連絡したい内容をユーザーに伝え、渡してもらう |
| `/名前` （例: `/create-pr` ）・`Skill` ツール | スキルを呼ぶ | `~/.agents/skills/<名前>/SKILL.md` を開いて手順に従う |
| `/config` などの組み込みのコマンド | Claude Code の設定や操作 | 手元の同じ役目の設定を使う。無ければその手順は飛ばす |
| `run_in_background` | コマンドをバックグラウンドで流す | 前景で流す |
| `mcp__<サーバー>__<ツール>` | MCP サーバーのツール | 同じサーバーが手元に繋がっていれば、その同じ名前のツールを使う。無ければ、やりたい操作をユーザーに伝える |
| サブエージェント（ `surveyor` など） | 別のエージェントに調べ物を任せる | 自分で調べる |
| フック（「フックが止める」など） | Claude Code が自動で走らせる検査 | 走らないので、その検査の中身を自分で守る |
| `WebSearch`・`WebFetch` | Web の検索と取得 | 手元の同じ役目の道具を使う |
| auto memory （ `MEMORY.md` ） | リポジトリごとの学習ノート | `~/.claude/projects/<作業ディレクトリのパスの / を - に置き換えた名前>/memory/MEMORY.md` があれば開いて読む |

## 資産の置き分け

| 置き場 | 役割 | いつ読まれるか |
| --- | --- | --- |
| `AGENTS.md` | この前提。Claude Code は上の階層の `.claude/AGENTS.md` として、Codex は `~/.codex/AGENTS.md` から読む | **毎セッション全文**（ホームの下で開いたとき） |
| `rules/*.md` | 振る舞いの規約。コミット・レビュー・報告の仕方 | **毎セッション全文**（ `paths` 付きは合うファイルを扱ったときだけ） |
| `skills/<name>/SKILL.md` | 手順書。複数ステップの作業 | 呼ばれたときだけ |
| `references/*.md` | ルールから移した、場面が限られる手順と実例。ルールが普通のパスで指す（ `rules/` の下に置くとサブフォルダまで常に読まれるので、外に置く） | ルールに指された場面で開いたときだけ |
| `settings.json` の `hooks` | ツール実行に反応する自動処理 | 該当ツールの実行時 |
| `agents/*.md` | 独自のサブエージェント定義 | 起動したときだけ |
| `output-styles/*.md` | 応答の役割・トーン・形式 | セッション開始時 |
| `projects/<project>/memory/` | **リポジトリ固有の事実**。自分が書く学習ノート | `MEMORY.md` の索引が毎セッション |

### サブエージェントは `surveyor` だけ自分の判断で呼ぶ

**エージェントの名前は行為者形**（ `surveyor` / `code-reviewer` ）。スキルは `動詞-目的語` （ `create-pr` ）なので、**名前の形だけでどちらか分かる**。

**既定は「明示指示があるときだけ」。** その例外が `surveyor` （列挙と分類）1本で、**こちらの判断で起動してよい**。

**スキルが種類を指定せずにサブエージェントを起動させるときも同じ。** 事実を調べるだけなら `surveyor` を使う（外から取り込んだ `/mattpocock-skills:grilling` がこの形）。種類を名指ししているスキルは、その指定に従う。

| | 自律起動 | なぜ |
| --- | --- | --- |
| **`surveyor`** | **してよい** | 読み取り専用で、規約もフックも効く。**探し方とコマンドと件数を必ず返す契約**があるので検算できる |
| `Explore` / `Plan` | しない | **指示（ `AGENTS.md` ）と rules を読まない仕様**。規約を知らない相手が判断することになる |
| `general-purpose` ほか | しない | 既定のまま |

**使うのは「読む量が多く、結論が短い」作業。** ただし短いだけでは足りず、**返ってきたものを検算できるか**で決める。

| 検算できるか | 投げるか |
| --- | --- |
| **結論だけで検算できる**（同じ対象へ自分で1回掛ければ済む） | **投げる** |
| **過程を返させれば検算できる**（どう探したか・件数が分かれば足りる） | **投げる。** `surveyor` の出力契約がこれ |
| **過程を全部読まないと判断できない** | **投げない。** 投げても結局自分で読むことになる |

数えるだけなら `grep` で足りる。判断の根拠として原文を読む必要がある作業（規約と差分の照合、反証）は3番目に当たる。

**pstack のスキルが手順として起動するサブエージェントは例外。** `how`・`why` のように、使うと決めたスキルが手順の中で起動するものは、そのスキルに任せる。並列で何本も動かすスキル（下記「プラグインのスキルとの使い分け」の最後の表）は、引き続きユーザーが指示したときだけ。

**常に効かせたいものは rules、呼ばれたときだけ効かせたいものは skills。** 書き方と整理の規約は `rules/rule_conventions.md` が両方を持つ。

**汎用の規約は rules、そのリポジトリだけの事実は memory。** どちらも毎セッション読まれるので、同じことを書くと二重にロードされる（ `/organize-rules` の「auto memory との境界」）。

### 公開側と非公開側

これらの実体は dotfiles リポジトリにあり、**`home/` は GitHub 上で全世界から読める**。

| 置く内容 | 置き場 |
| --- | --- |
| 汎用の規約・手順 | `home/` （公開） |
| **社内の呼称・リポジトリ名・GitHub ID・プロダクトの状況** | **`private/` （非公開）** |

**迷ったら `private/` に倒す。** 公開してしまうと取り消せない（履歴の書き換えが要る）。判断表は dotfiles の `docs/placement.md`、点検は同リポジトリの `/audit-secrets` スキル。

**auto memory も dotfiles 管理下**（ `private/.claude-memory/<project>/` の実体へシンボリックリンク）。リポジトリ固有の事情を書く場所なので、公開側には置かない。スキルは**1本ずつ置き場が違う**ので、編集前にリンク先を確かめる。

**編集した時点で dotfiles の作業ツリーが汚れる。** コミットは dotfiles 側の担当セッションへ依頼する（ `rules/notify_related_repo_sessions.md` ）。

`commands/*.md` は skills に統合済み。既存ファイルは動き続けるが、**新規はすべて skills に置く**。

## プラグインのスキルとの使い分け

汎用の手順は pstack と mattpocock-skills に積極的に委ねる。手元のスキルを書く・直すときは、同じ手順を両プラグインが持っていないかを先に見て、持っていればそのスキルを呼ぶ。手元のスキルとルールに残すのは、ユーザー固有の方針（尋ね方・書き方・扱うリポジトリの事情）だけ。重なる場面は次のとおり振り分ける。

**Skill ツールが拒否するスキルは、SKILL.md を Read して従う。** pstack は `setup-pstack` 以外、mattpocock-skills も一部が `disable-model-invocation: true` で、AI からは呼べない。置き場は `~/.claude/plugins/cache/<マーケットプレイス>/<プラグイン>/<版>/` の下。pstack は、最初に同じ場所の `docs/harness/claude-code.md` を1回読む（Cursor の名前を Claude Code の名前へ読み替える表がある）。手元のスキルが「pstack の `how` に従う」と書いているのも、この読み方を指す。

| 場面 | 使うもの |
| --- | --- |
| 設計・複数のファイルにまたがる変更・原因の分からない不具合・性能 | `/pstack:poteto-mode` を入口にする。やることが決まっていれば `/pstack:architect`・`/pstack:how`・`/pstack:why` へ直接入る。原因の分からない不具合は `/mattpocock-skills:diagnosing-bugs` の進め方で絞り、直すときは pstack の `principle-fix-root-causes` （症状ではなく最初に誤った箇所を直す）に従う。同じ前提の修正が続けて失敗したら `principle-attack-the-premise` で前提を疑う |
| テストを先に書く実装 | `/pstack:tdd` |
| 計画・壁打ち | `/plan-issue`・`/mattpocock-skills:grilling` |
| コードや変更を噛み砕いて説明する | `/explain-code`・`/walk-code` （ユーザーの習熟度に合わせて開く）。仕組みや経緯を調べる段は `/pstack:how`・`/pstack:why` を単独で使ってよい |
| コードレビュー（する・受ける） | `/review-*`・`/resolve-*`・`rules/responding_to_reviews.md`。コードの不吉な臭いの一覧は `/mattpocock-skills:code-review` から、抽象化の深さの語彙は `/mattpocock-skills:codebase-design` から、`/review-code` が参照する |
| PR を出す・仕上げる・CI・コンフリクト | `/ship-pr`・`/finalize-prs`・`/loop-ai-reviews`・`/resolve-conflicts` |
| 文章 | 日本語は `/japanese-tech-writing` → `/yomiyasu:yomiyasu` （ `rules/no_ai_style_writing.md` ）。pstack の `unslop`・`technical-writing` は英語の文章にだけ使う |
| 完了前の検証 | `rules/verify_the_check_worked.md`・`rules/verify_before_asserting.md` |
| ルールとスキルの書き方 | `/organize-rules`・`/learn-rules`。一般的な書き方は `/mattpocock-skills:writing-for-agents` から、繰り返す誤りを構造で止める順序は `/pstack:correct` から、`/organize-rules` が参照する |
| 依存の更新で壊れる先・性能の数字の検算 | `/resolve-renovate-pr` が `/pstack:blast-radius` を使う。速さを測って報告するときは `/pstack:benchmark-checklist` を通す（ `references/base_records_on_measurements.md` ） |

pstack（ `poteto-mode` ）が求めることのうち、次は手元のルールを優先する。

| pstack の求めること | 優先するルール |
| --- | --- |
| 返信を英語の口語で書く（ `teach` などの「plain spoken English」） | 上記「ユーザーについて」の日本語の応答。スキルの手順は従い、返す文章だけを日本語にする |
| 返信を `unslop` に通す・返信の中で判断に使った原則を名前で挙げる | `rules/concise_first_then_detail.md` （一言目で答え、自己解説を混ぜない）。その場の応答は文章の点検に通さない |
| 「どの案にするか」は尋ねずに試作して決める | `rules/decide_or_ask.md`。取り消せない操作とユーザーの領分は `AskUserQuestion` で尋ねる |
| 並列でサブエージェントを動かすスキル（ `arena`・`swarm`・`architect` の並列探索・`interrogate`・`reflect`・`no-comments` ） | ユーザーが指示したときだけ使う。自分の判断で呼ぶのは `surveyor` だけ（上記「サブエージェントは `surveyor` だけ自分の判断で呼ぶ」） |

## 会話が要約されるとき

要約には次を必ず残す。要約のあとは、ここが抜けた状態から作業を続けることになる。

- 触ったファイルと、未コミット・未 push の状態
- ほかのセッションから受けて、まだ終わっていない依頼（相手の名前と中身）
- ユーザーに尋ねて答えを待っているもの、ユーザーから受けてまだ終わっていない指示

## 迷ったとき

- 断定の前に一次情報で裏を取る（ `rules/verify_before_asserting.md` ）
- 結論を先に、全体は簡潔に（ `rules/concise_first_then_detail.md` ）
- コミット・push・レビュー依頼（ready 化と再依頼）は明示指示があるときだけ（ `rules/decide_or_ask.md`、`rules/no_auto_ready_pr.md` ）
