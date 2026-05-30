---
name: ai-search-decommission
description: "Remove Azure AI Search from the AzureSREAgentDemoLab SRE Agent demo. WHEN: the SRE Agent no longer uses Azure AI Search, AI_SEARCH outputs or srch-* resources still exist, a previously deployed Microsoft.Search/searchServices needs cleanup, infra/modules/ai-search.bicep references must be removed, or azd postprovision still runs setup-ai-search."
license: MIT
metadata:
  author: GitHub Copilot
  version: "0.1.0"
---

# AI Search Decommission

Use this skill to remove Azure AI Search from the demo, both in infrastructure
(Bicep) and at runtime (already-deployed resources). The SRE Agent stores
operational knowledge in its own agent memory and no longer depends on Azure AI
Search.

## Applies to

- `infra/main.bicep` still declaring an `aiSearch` module or `AI_SEARCH_*` outputs
- `infra/modules/ai-search.bicep` present in the repo
- `azure.yaml` `postprovision` hook running `setup-ai-search.*`
- A resource group that still contains a `Microsoft.Search/searchServices` resource

## Infrastructure changes

1. In `infra/main.bicep`, remove:
   - the `searchServiceName` variable
   - the `module aiSearch './modules/ai-search.bicep'` block
   - the `AI_SEARCH_ENDPOINT` and `AI_SEARCH_NAME` outputs
2. Delete `infra/modules/ai-search.bicep`.
3. In `azure.yaml`, remove the `postprovision` hook that runs `setup-ai-search.ps1` / `.sh`.
4. Validate: `az bicep build --file infra/main.bicep` (warnings about resource type
   versions are pre-existing and safe to ignore).

## Decommission already-deployed AI Search

Run the idempotent cleanup script. It finds every `Microsoft.Search/searchServices`
in the resource group and deletes it; it succeeds with no changes when none exist.

```bash
# Bash (macOS/Linux)
scripts/remove-ai-search.sh <resource-group> [--subscription <id>] [--yes]
```

```powershell
# PowerShell 7
scripts/remove-ai-search.ps1 -ResourceGroup <name> [-SubscriptionId <id>] [-Yes]
```

When this skill is loaded together with the `sre-demo-helper` extension, you can
also invoke the `sre_decommission_ai_search` tool directly.

## Verification

```bash
az resource list -g <resource-group> --resource-type Microsoft.Search/searchServices -o table
```

The list must be empty. Confirm `infra/main.bicep` has no `search` references and
that `azure.yaml` no longer defines the `setup-ai-search` hook.
