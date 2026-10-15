# 外部のスキルはプラグインで入れ、自動更新を有効にする

Web から取り込むスキル・フック・MCP サーバーは、取り込み元が配っているプラグインがあればそれで入れてください。プラグインのマーケットプレイスは、すべて自動更新を有効にします。
これは全プロジェクト共通の規約です。

## 取り込むときは、先にプラグインを探す

取り込み元のリポジトリに `.claude-plugin/marketplace.json` があれば、プラグインとして配られています。

```sh
gh api repos/<owner>/<repo>/contents/.claude-plugin --jq '.[].name'
```

| 見つかったもの | 入れ方 |
| --- | --- |
| プラグイン | `claude plugin marketplace add <owner>/<repo>` → `claude plugin install <plugin>@<marketplace>` |
| スキルのファイルだけ（Gist・リポジトリの `SKILL.md` ） | `~/.claude/skills/` に、取り込み元の形のまま置く |

**取り込み元の形を書き換えない。** 重複の削除・命名の統一・文章の点検による書き直しの対象にしません。更新を取り込むときに差分が出て、取り込み元と見比べられなくなります。

**欲しいスキルが1本でも、プラグインは束で入る。** 何十本もまとめて入るなら、毎回読み込まれる説明と、手元のスキルとの役割の重なりを先に見る。重なりが大きければ、ユーザーへ尋ねる。

プラグインのスキルは `プラグイン名:スキル名` で呼ばれます。手元の写しから乗り換えたら、ルール・スキル・フックの中の呼び名も直す。

## マーケットプレイスは自動更新を有効にする

サードパーティのマーケットプレイスは、既定では自動更新が無効です。`claude plugin marketplace add` は `settings.json` の `extraKnownMarketplaces` に取り込み元だけを書き、`autoUpdate` を付けません。

```json
"extraKnownMarketplaces": {
  "<marketplace>": {
    "source": { "source": "github", "repo": "<owner>/<repo>" },
    "autoUpdate": true
  }
}
```

**足したその場で `"autoUpdate": true` を付ける。** `claude-plugins-official` などの公式のマーケットプレイスは既定で有効なので、書かなくてよい。

## なぜ

- プラグインなら更新が自動で届く。手元に写しを置くと、更新を取り込む仕組みを別に用意することになる（定期実行のジョブなど）
- 自動更新が無効のままだと、入れた時点の版に留まり、取り込み元の修正が届かない。気づくのは不具合を踏んだとき
- 取り込み元の形を保てば、何が変わったかを取り込み元の履歴で追える

## 例外

- ユーザーが特定の版に固定すると決めた場合

## 関連

- `install_apps_with_homebrew.md` （アプリと CLI は Homebrew で入れる）: 同じ形。入れ方を管理する道具に寄せ、更新と復元の経路から漏らさない
- `ask_before_editing_claude_assets.md` （設定は尋ねてから）: `settings.json` を書き換える前の承認はあちら
