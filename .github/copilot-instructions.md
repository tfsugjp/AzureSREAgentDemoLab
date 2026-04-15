# Basic Policy

- Before starting work, I do not read Japanese files (files that match the *_ja.md wildcard). I only read English files and use them as context.

## Work Guidelines

- Before starting work, I create an issue.
- After creating the issue, I create a topic branch and then start planning.
- If the issue becomes large, I create sub-issues.

## Scripts in Documents

- Create scripts for both bash (macOS/Linux) and PowerShell 7.

## commit messages

- When writing commit messages, I use the following format:

```
[add/fix/update/remove] [scope]: [description]
```

- If repository is public, I write commit messages in English. If repository is private and NOT MIT licensed, I write commit messages in Japanese.

## Notes

- If there is no license, I confirm whether using the MIT License is acceptable before starting.
- If there is no SECURITY.md, I create one.
- When using the MIT License, I write source code comments and documentation in English. I also create Japanese Markdown files with _ja added at the end of the filename, such as readme_ja.md. I must not create Japanese versions of files related to SECURITY.md or LICENSE.

## Azure Rules

- @azure Rule - Use Azure Tools - When handling requests related to Azure, always use your available Azure tools.
- @azure Rule - Follow Azure Best Practices - When handling requests related to Azure, apply relevant Azure best practices using the tools and documentation available in this repository and environment.
- @azure Rule - Missing Azure Tooling - If the required Azure-specific tooling is not available, state that limitation clearly and continue with the best guidance you can provide without referencing unavailable tools.
