// Extension: sre-demo-helper
// Demo helper tools and guardrails for the AzureSREAgentDemoLab SRE Agent demo.
//
// Provides:
//   - Tools that wrap the repository demo scripts (cross-platform: pwsh on
//     Windows, bash elsewhere) so the agent can run common demo operations.
//   - A guardrail hook that protects Japanese documentation (*_ja.md) from
//     accidental deletion.
//   - A session-start hook that injects this repo's conventions as context.

import { joinSession } from "@github/copilot-sdk/extension";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import path from "node:path";

const execFileAsync = promisify(execFile);

const extensionDir = path.dirname(fileURLToPath(import.meta.url));
// .github/extensions/sre-demo-helper -> repo root is three levels up.
const repoRoot = path.resolve(extensionDir, "..", "..", "..");
const scriptsDir = path.join(repoRoot, "scripts");
const isWindows = process.platform === "win32";

// Runs a repo script by base name, choosing the .ps1/.sh variant per platform.
async function runScript(baseName, args, logger) {
    const file = isWindows
        ? path.join(scriptsDir, `${baseName}.ps1`)
        : path.join(scriptsDir, `${baseName}.sh`);
    const command = isWindows ? "pwsh" : "bash";
    const cmdArgs = isWindows
        ? ["-NoProfile", "-File", file, ...args]
        : [file, ...args];
    await logger(`Running: ${command} ${cmdArgs.join(" ")}`);
    try {
        const { stdout, stderr } = await execFileAsync(command, cmdArgs, {
            cwd: repoRoot,
            timeout: 15 * 60 * 1000,
            maxBuffer: 16 * 1024 * 1024,
        });
        const out = [stdout, stderr].filter(Boolean).join("\n").trim();
        return { textResultForLlm: out || "(no output)", resultType: "success" };
    } catch (err) {
        const out = [err.stdout, err.stderr, err.message]
            .filter(Boolean)
            .join("\n")
            .trim();
        return { textResultForLlm: out, resultType: "failure" };
    }
}

// Returns true when a tool invocation would delete a Japanese doc (*_ja.md) or
// the knowledge-base directory. Tool-aware to avoid false positives on prose
// that merely mentions a filename.
function wouldDeleteJapaneseDoc(toolName, toolArgs) {
    const name = String(toolName || "").toLowerCase();
    const jaDoc = /_ja\.md\b/;

    // apply_patch / patch-style tools: look for explicit delete-file hunks.
    if (typeof toolArgs === "string") {
        if (/\*\*\*\s*Delete File:\s*\S*_ja\.md/i.test(toolArgs)) return true;
    }
    const patchText =
        (toolArgs && (toolArgs.input || toolArgs.patch || toolArgs.content)) || "";
    if (typeof patchText === "string" && /\*\*\*\s*Delete File:\s*\S*_ja\.md/i.test(patchText)) {
        return true;
    }

    // Structured delete tools (delete/remove/unlink) with a path argument.
    if (/(delete|remove|unlink|rm)/.test(name) && toolArgs && typeof toolArgs === "object") {
        for (const key of ["path", "file", "filePath", "target", "name"]) {
            const v = toolArgs[key];
            if (typeof v === "string" && (jaDoc.test(v) || /data\/sre-knowledge\/?$/.test(v))) {
                return true;
            }
        }
    }

    // Shell-style tools: a delete verb combined with a *_ja.md token, or an
    // explicit recursive delete of the knowledge-base directory.
    const command =
        (toolArgs && typeof toolArgs === "object" && (toolArgs.command || toolArgs.cmd || toolArgs.script)) ||
        (typeof toolArgs === "string" ? toolArgs : "");
    if (typeof command === "string" && command) {
        const deleteVerb = /\b(rm|del|Remove-Item|git\s+rm|unlink)\b/i;
        if (deleteVerb.test(command) && jaDoc.test(command)) return true;
        if (/\bfind\b[^|]*-delete/i.test(command) && jaDoc.test(command)) return true;
        if (deleteVerb.test(command) && /data\/sre-knowledge\b/.test(command)) return true;
    }

    return false;
}

const session = await joinSession({
    tools: [
        {
            name: "sre_decommission_ai_search",
            description:
                "Decommission (delete) any Azure AI Search service in a resource group. The SRE Agent no longer uses AI Search. Idempotent: succeeds with no changes when none exist.",
            parameters: {
                type: "object",
                properties: {
                    resourceGroup: { type: "string", description: "Target resource group." },
                    subscriptionId: { type: "string", description: "Optional subscription ID." },
                },
                required: ["resourceGroup"],
            },
            handler: async (args, _invocation) => {
                const cliArgs = isWindows
                    ? ["-ResourceGroup", args.resourceGroup, "-Yes"]
                    : [args.resourceGroup, "--yes"];
                if (args.subscriptionId) {
                    cliArgs.push(isWindows ? "-SubscriptionId" : "--subscription", args.subscriptionId);
                }
                return runScript("remove-ai-search", cliArgs, (m) => session.log(m, { ephemeral: true }));
            },
        },
        {
            name: "sre_upload_knowledge",
            description:
                "Upload the Markdown SRE knowledge base (data/sre-knowledge) to an Azure SRE Agent's memory. Choose English, Japanese, or both with the language argument.",
            parameters: {
                type: "object",
                properties: {
                    resourceGroup: { type: "string", description: "Resource group of the SRE Agent." },
                    agentName: { type: "string", description: "SRE Agent resource name." },
                    language: {
                        type: "string",
                        enum: ["en", "ja", "all"],
                        description: "Which knowledge files to upload (default en).",
                    },
                    subscriptionId: { type: "string", description: "Optional subscription ID." },
                },
                required: ["resourceGroup", "agentName"],
            },
            handler: async (args, _invocation) => {
                const lang = args.language || "en";
                const cliArgs = isWindows
                    ? ["-ResourceGroup", args.resourceGroup, "-AgentName", args.agentName, "-Language", lang]
                    : ["-g", args.resourceGroup, "-n", args.agentName, "--language", lang];
                if (args.subscriptionId) {
                    cliArgs.push(isWindows ? "-SubscriptionId" : "--subscription", args.subscriptionId);
                }
                return runScript("upload-sre-knowledge", cliArgs, (m) => session.log(m, { ephemeral: true }));
            },
        },
        {
            name: "sre_verify_setup",
            description:
                "Verify that the SRE Agent demo resources are correctly deployed and configured in a resource group.",
            parameters: {
                type: "object",
                properties: {
                    resourceGroup: { type: "string", description: "Target resource group." },
                    environmentName: { type: "string", description: "azd environment name." },
                },
                required: ["resourceGroup", "environmentName"],
            },
            handler: async (args, _invocation) => {
                const cliArgs = isWindows
                    ? ["-ResourceGroup", args.resourceGroup, "-EnvironmentName", args.environmentName]
                    : ["-g", args.resourceGroup, "-e", args.environmentName];
                return runScript("verify-sre-setup", cliArgs, (m) => session.log(m, { ephemeral: true }));
            },
        },
    ],
    hooks: {
        // Protect Japanese documentation from accidental deletion.
        onPreToolUse: async (input) => {
            if (wouldDeleteJapaneseDoc(input?.toolName, input?.toolArgs)) {
                return {
                    permissionDecision: "deny",
                    permissionDecisionReason:
                        "Deleting Japanese documentation (*_ja.md) is not allowed in this repository. Japanese docs must be preserved.",
                };
            }
            return undefined;
        },
        // Inject repository conventions so the agent follows them automatically.
        onSessionStart: async () => ({
            additionalContext: [
                "AzureSREAgentDemoLab conventions:",
                "- License: MIT. Code comments and documentation in English; provide Japanese copies as *_ja.md.",
                "- Never delete Japanese documents (*_ja.md).",
                "- Files use LF line endings and UTF-8 without BOM.",
                "- SRE knowledge base lives in data/sre-knowledge as Markdown (English kb-*.md + Japanese kb-*_ja.md).",
                "- The SRE Agent no longer uses Azure AI Search.",
            ].join("\n"),
        }),
    },
});

await session.log("sre-demo-helper extension ready", { ephemeral: true });
