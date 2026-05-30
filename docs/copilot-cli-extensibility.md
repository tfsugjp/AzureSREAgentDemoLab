# GitHub Copilot CLI Extensibility for the SRE Demo

This repository ships GitHub Copilot CLI extensibility to streamline running and
maintaining the SRE Agent demo. Three mechanisms are used: **skills**,
**extensions (plugins)**, and **hooks**.

## Components

### Skills (`.github/skills/`)

Skills are Markdown playbooks the agent loads on demand when the task matches
their description.

| Skill | Use it when |
|---|---|
| `ai-search-decommission` | Removing Azure AI Search from Bicep and deleting already-deployed `Microsoft.Search/searchServices`. |
| `sre-knowledge-author` | Authoring/editing Markdown runbooks in `data/sre-knowledge` and uploading them to the SRE Agent in English, Japanese, or both. |
| `logic-app-alert-relay-fix` | Diagnosing a Logic App relay that fails before creating downstream GitHub/Azure DevOps tickets. |

### Extension / plugin (`.github/extensions/sre-demo-helper`)

An `extension.mjs` that registers agent **tools** wrapping the repository scripts
(cross-platform: `pwsh` on Windows, `bash` elsewhere):

| Tool | Wraps |
|---|---|
| `sre_decommission_ai_search` | `scripts/remove-ai-search.{sh,ps1}` |
| `sre_upload_knowledge` | `scripts/upload-sre-knowledge.{sh,ps1}` (language: `en`/`ja`/`all`) |
| `sre_verify_setup` | `scripts/verify-sre-setup.{sh,ps1}` |

### Hooks (in `sre-demo-helper`)

- `onPreToolUse` — **guardrail**: denies any tool call that would delete a
  Japanese document (`*_ja.md`). Japanese docs must be preserved.
- `onSessionStart` — injects repository conventions (MIT, English + `*_ja.md`,
  LF / UTF-8 without BOM, Markdown knowledge base location, no Azure AI Search)
  so the agent follows them automatically.

## Additional usage scenarios

Beyond the components above, skills and extension tools are useful for:

1. **One-command demo bootstrap** — chain `sre_verify_setup` then
   `sre_upload_knowledge` to validate resources and seed the knowledge base.
2. **Incident rehearsal** — pair the demo tools with the `logic-app-alert-relay-fix`
   skill to trigger an incident and walk the relay path end to end.
3. **Knowledge base sync** — after editing any `data/sre-knowledge/*.md`, re-upload
   with `sre_upload_knowledge` so agent memory matches the repository.
4. **Cost cleanup** — run `sre_decommission_ai_search` after a workshop to remove
   any lingering AI Search resource.
5. **Convention enforcement** — the `onPreToolUse` guardrail and `onSessionStart`
   context keep contributions aligned with repo rules without manual reminders.

## Activating

- **Skills** load automatically from `.github/skills/` when their description
  matches the task.
- **Extensions** load from `.github/extensions/`. After editing
  `extension.mjs`, reload them in the CLI so new tools appear.

## References

- Extension authoring: GitHub Copilot CLI extension SDK (`@github/copilot-sdk/extension`)
- Azure SRE Agent data plane API: https://learn.microsoft.com/en-us/azure/sre-agent/api-reference
