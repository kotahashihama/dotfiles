---
description: 【他スキルから呼ばれる部品】GitHub Actions のワークフロー完了をバックグラウンドで待つ。「起動したか」と「終わったか」を両方の条件で判定し、古い run を掴んで即座に抜ける事故を防ぐ。PR に push した後や slash command でワークフローを起動した後、完了を待ちたいときに使う。
argument-hint: "[ワークフロー名 または PR 番号] [--event イベント名]"
user-invocable: false
allowed-tools: Bash(gh run list:*) Bash(gh run view:*) Bash(gh pr checks:*) Bash(gh pr view:*) Bash(git branch:*) Bash(sleep:*) Bash(while:*) Bash(until:*)
---

GitHub Actions の完了を待ちます。**待てているつもりで待てていない**のがこのタスクの唯一かつ最大の失敗モードで、それを潰すのがこのスキルの目的です。

## 待機の述語 (ここを間違えると全部壊れる)

### 起動前に「直前の run ID」を控える

**「最新 run が completed か」だけを見てはいけない。** 過去の run が既に完了していると、その場で条件を満たして即座に抜けます。**新しく発火した run かどうか**を ID で判別します。

```bash
prev=$(gh run list --workflow "<name>" --event <event> --limit 1 --json databaseId -q '.[0].databaseId')
```

run が1件も無ければ空文字でよい。**ワークフローを起動する前に取る**のが要点です。

### `--branch` で絞らない (イベントによって headBranch が変わる)

| 起動のしかた | `headBranch` |
| --- | --- |
| push / PR の作成・更新 | feature ブランチ |
| **PR コメントの slash command (`issue_comment`)** | **base ブランチ (`main`)** |
| `workflow_dispatch` | 指定したブランチ |

`issue_comment` 起点を feature ブランチで絞ると**永久に引っかかりません**。`--event` で絞るのが確実です。

### 時刻でのカットオフは使わない

「起動時刻より後の run」を条件にすると、時計のずれや `createdAt` の粒度で対象を取り逃がし、**永久に待ちます**。ID の比較で判定します。

## 進め方

### 1. 対象の特定

- ワークフロー名は `.github/workflows/` の `name:` と一致させる（リポジトリごとに揺れる）
- イベントは起動のしかたから決める。slash command なら `issue_comment`、push なら `push` / `pull_request`
- 起動前に**直前の run ID** を控える（上記）

### 2. バックグラウンドで待つ

**Bash ツールを `run_in_background: true` で1回だけ起動する。** ポーリング用に Bash を何度も打つのは、通知機構を使わずに手で待つのと同じで無駄です。

```bash
prev=<起動前の run ID>
while true; do
  row=$(gh run list --workflow "<name>" --event <event> --limit 1 \
    --json databaseId,status,conclusion -q '.[0] | "\(.databaseId) \(.status) \(.conclusion // "-")"')
  id=$(echo "$row" | cut -d' ' -f1); st=$(echo "$row" | cut -d' ' -f2)
  if [ "$id" != "$prev" ] && [ "$st" = "completed" ]; then echo "$row"; break; fi
  sleep 20
done
```

**待っている間、メインループは他の作業に手を出さない。** 完了通知で再開します。

### 3. 結果の解釈

`conclusion` をそのまま報告せず、**意味まで見る**。

| conclusion | 見るべきこと |
| --- | --- |
| `success` | そのまま次へ |
| `failure` | **原因がコードかどうか**。`gh run view <id> --log-failed` の末尾を読む。レビュー承認待ち (`approval required`) 等、コードと無関係な失敗がある |
| `cancelled` | 後続の run に置き換わった可能性。再度 run list を見る |
| `skipped` | **条件で除外された**。draft PR では走らない設定のことがある。待つ対象を間違えていないか疑う |

### 4. 報告

run ID / conclusion / URL を1行で返す。`failure` なら**原因の分類**（コード起因 / 承認待ち / インフラ）まで添える。

## 出力の目安

- 成功時: 1〜2行（run ID と conclusion、次に何ができるか）
- 失敗時: conclusion + 原因の分類 + ログの該当行。**ログ全文は貼らない**

## してはいけないこと

- **`--branch <feature>` で絞ること**（`issue_comment` 起点を取りこぼす）
- **「最新 run が completed か」だけで判定すること**（古い run で即座に抜ける）
- 時刻をカットオフに使うこと（取り逃がして永久に待つ）
- フォアグラウンドで待つこと（メインループが長時間ブロックされる）
- 完了通知を待たずに自前ポーリングを繰り返すこと
- `failure` を原因を見ずに「壊れている」と報告すること
- タイムアウトを設けずに待ち続けること。**30分を超えたら中断**して状況を報告する
