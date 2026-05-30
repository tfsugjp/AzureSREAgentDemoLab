---
name: sre-knowledge-author
description: "Author, maintain, and upload the AzureSREAgentDemoLab SRE Agent knowledge base as Markdown. WHEN: adding or editing runbooks under data/sre-knowledge, converting knowledge to Markdown, keeping English (kb-*.md) and Japanese (kb-*_ja.md) copies in sync, or uploading knowledge to an Azure SRE Agent's memory in English, Japanese, or both."
license: MIT
metadata:
  author: GitHub Copilot
  version: "0.1.0"
---

# SRE Knowledge Author

Use this skill to manage the SRE Agent knowledge base. Knowledge lives as Markdown
runbooks in `data/sre-knowledge/`, replacing the former Azure AI Search JSON index.
Each entry exists in two languages so the operator can choose which to register:

- `kb-XXX.md` — English (canonical)
- `kb-XXX_ja.md` — Japanese

Never delete the Japanese (`*_ja.md`) files.

## File format

Each runbook starts with YAML front matter, then a Markdown body:

```markdown
---
id: kb-021
title: "Short English title"
category: troubleshooting   # troubleshooting | runbook | architecture | reference
service: CatalogService     # CatalogService | OrderService | NotificationService | all
severity: high              # critical | high | medium | low
tags: [tag1, tag2]
lastUpdated: 2026-04-01T00:00:00Z
---

# Short English title

## Symptoms
...
## Root Cause
...
## Resolution
...
```

The Japanese copy uses the same front matter (with a Japanese `title`) and a
translated body. Do not translate code blocks, commands, file names, identifiers,
API paths, or quoted log strings.

## Authoring a new runbook

1. Pick the next `kb-XXX` id.
2. Create the English `data/sre-knowledge/kb-XXX.md`.
3. Create the Japanese `data/sre-knowledge/kb-XXX_ja.md` with the same metadata and
   a translated body.
4. Keep both copies in sync whenever either changes.

## Uploading to the SRE Agent

The SRE Agent stores knowledge in its agent memory (data plane:
`POST /api/v1/agentmemory/upload`). Use the upload script and choose the language:

```bash
# Bash (macOS/Linux) — language: en (default) | ja | all
scripts/upload-sre-knowledge.sh -g <resource-group> -n <agent-name> --language all
```

```powershell
# PowerShell 7
scripts/upload-sre-knowledge.ps1 -ResourceGroup <name> -AgentName <name> -Language all
```

When the `sre-demo-helper` extension is loaded, the `sre_upload_knowledge` tool
performs the same upload with a `language` argument.

## References

- Azure SRE Agent knowledge: https://learn.microsoft.com/en-us/azure/sre-agent/upload-knowledge-document
- Data plane API: https://learn.microsoft.com/en-us/azure/sre-agent/api-reference
