# SRE デモ向け GitHub Copilot CLI 拡張

このリポジトリは、SRE Agent デモの実行・保守を効率化するための GitHub Copilot CLI
拡張を同梱しています。利用する仕組みは **skill**、**extension (plugin)**、**hook**
の 3 つです。

## コンポーネント

### Skills (`.github/skills/`)

Skill は、タスクが説明に一致したときにエージェントが必要に応じて読み込む Markdown
プレイブックです。

| Skill | 使用する場面 |
|---|---|
| `ai-search-decommission` | Bicep からの Azure AI Search 削除、デプロイ済み `Microsoft.Search/searchServices` の削除。 |
| `sre-knowledge-author` | `data/sre-knowledge` の Markdown ランブックの作成・編集、英語/日本語/両方での SRE Agent へのアップロード。 |
| `logic-app-alert-relay-fix` | ダウンストリームの GitHub / Azure DevOps チケット作成前に失敗する Logic App リレーの診断。 |

### Extension / plugin (`.github/extensions/sre-demo-helper`)

リポジトリのスクリプトをラップしたエージェント **ツール** を登録する
`extension.mjs` です (クロスプラットフォーム: Windows は `pwsh`、それ以外は `bash`)。

| ツール | ラップ対象 |
|---|---|
| `sre_decommission_ai_search` | `scripts/remove-ai-search.{sh,ps1}` |
| `sre_upload_knowledge` | `scripts/upload-sre-knowledge.{sh,ps1}` (言語: `en`/`ja`/`all`) |
| `sre_verify_setup` | `scripts/verify-sre-setup.{sh,ps1}` |

### Hooks (`sre-demo-helper` 内)

- `onPreToolUse` — **ガードレール**: 日本語ドキュメント (`*_ja.md`) を削除しよう
  とするツール呼び出しを拒否します。日本語ドキュメントは保持する必要があります。
- `onSessionStart` — リポジトリの規約 (MIT、英語 + `*_ja.md`、LF / BOM なし UTF-8、
  Markdown ナレッジベースの場所、Azure AI Search 不使用) をコンテキストとして注入し、
  エージェントが自動的に従うようにします。

## 追加の活用シナリオ

上記コンポーネントに加えて、skill と extension ツールは以下の場面でも役立ちます。

1. **ワンコマンドのデモ初期化** — `sre_verify_setup` の後に `sre_upload_knowledge`
   を続けて実行し、リソース検証とナレッジベース投入を行う。
2. **インシデントのリハーサル** — デモツールと `logic-app-alert-relay-fix` skill を
   組み合わせ、インシデントを発生させてリレー経路をエンドツーエンドで確認する。
3. **ナレッジベースの同期** — `data/sre-knowledge/*.md` を編集した後に
   `sre_upload_knowledge` で再アップロードし、エージェントのメモリをリポジトリと一致させる。
4. **コストのクリーンアップ** — ワークショップ後に `sre_decommission_ai_search` を実行し、
   残存する AI Search リソースを削除する。
5. **規約の徹底** — `onPreToolUse` ガードレールと `onSessionStart` コンテキストにより、
   手動の注意喚起なしにコントリビューションをリポジトリのルールに沿わせる。

## 有効化

- **Skill** は `.github/skills/` から、説明がタスクに一致したときに自動的に読み込まれます。
- **Extension** は `.github/extensions/` から読み込まれます。`extension.mjs` を編集した
  後は、CLI で再読み込みすると新しいツールが利用可能になります。

## 参考

- 拡張のオーサリング: GitHub Copilot CLI 拡張 SDK (`@github/copilot-sdk/extension`)
- Azure SRE Agent データプレーン API: https://learn.microsoft.com/en-us/azure/sre-agent/api-reference
