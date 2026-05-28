---
name: logic-app-alert-relay-fix
description: "Troubleshoot and fix a Logic App alert relay when Azure Monitor triggers a workflow but the run fails before creating downstream GitHub issues or Azure DevOps work items. WHEN: Logic App trigger problem, `For_each` tables null, Action Group callback URL mismatch, GitHub/Azure DevOps connector suspected, Azure Monitor common alert schema mismatch, downstream ticket creation missing."
license: MIT
metadata:
  author: GitHub Copilot
  version: "0.2.0"
---

# Logic App Alert Relay Fix

Use this skill when an Azure Monitor alert successfully calls a Logic App, but the Logic App run fails or downstream GitHub / Azure DevOps tickets are missing.

## Applies to

- Logic App HTTP triggers invoked by Azure Monitor Action Groups
- Logic App workflows that fan out alert payloads with `For each`
- Azure Monitor relay patterns that create downstream tickets in GitHub and Azure DevOps
- Common alert schema payloads from Azure Monitor metric alerts

## Typical symptoms

- Azure Monitor alert fires, but no downstream ticket appears
- Logic App run fails before `Create an issue` or `Create a work item`
- `For_each` fails with:
  - `ExpressionEvaluationFailed`
  - `@triggerOutputs()?['body']?['tables']` is `Null`
- GitHub / Azure DevOps connectors are suspected even though the failure happens earlier
- Action Group appears configured, but the Logic App never runs

## Common architecture pattern

Expected flow:

1. Azure Monitor metric alert fires
2. Action Group calls the Logic App HTTP trigger
3. Logic App processes the alert payload
4. GitHub issue is created through an API connection
5. Azure DevOps work item is created through an API connection

Common workflow shape:

- `When an HTTP request is received`
- `For each`
- `Create an issue`
- `Create a work item`

Adapt the action names if your workflow uses different names.

## First diagnosis rule

Before repairing connectors, determine **where** the run fails.

### If the run fails at `For each`

Do **not** start by reauthorizing GitHub or Azure DevOps.

This usually means the workflow expects the wrong payload shape from Azure Monitor.

### If the Logic App never runs at all

Check the Action Group callback URL first.

## Failure mode 1: Action Group callback URL is wrong

If Azure Monitor shows the Action Group receiver but the Logic App never gets invoked, verify the Action Group is using the **trigger callback URL**, not the Logic App overview URL.

### Required callback URL shape

The callback URL must include both:

- `/triggers/`
- `sig=`

Example shape:

```text
https://.../workflows/.../triggers/When_an_HTTP_request_is_received/paths/invoke?...&sig=...
```

### What to validate

- `incidentRelayCallbackUrl` was taken from `listCallbackUrl`
- The stored Action Group receiver callback URL exactly matches the trigger callback URL
- The URL is not truncated to the workflow root URL

## Failure mode 2: `For each` expects `body.tables`

This is the most likely issue when the run fails with:

```text
ExpressionEvaluationFailed
The execution of template action 'For_each' failed: the result of the evaluation of 'foreach' expression '@triggerOutputs()?['body']?['tables']' is of type 'Null'. The result must be a valid array.
```

### Root cause

The workflow is assuming a payload with `body.tables`, but Azure Monitor is sending a **common alert schema** payload where the useful object is under:

```text
triggerBody()?['data']
```

### Fix

Change the `For each` items expression from:

```text
@triggerOutputs()?['body']?['tables']
```

To:

```text
@createArray(triggerBody()?['data'])
```

This is appropriate when you want the loop to execute once per alert and treat the alert `data` object as the loop item.

### Optional defensive version

Use this if you want an empty array instead of a hard failure when `data` is missing:

```text
@if(equals(triggerBody()?['data'], null), createArray(), createArray(triggerBody()?['data']))
```

## Failure mode 3: GitHub action is wired to the wrong repository or wrong payload fields

Even after fixing `For each`, the GitHub step can still fail if the action uses the wrong owner/repository name or treats the foreach item as a plain string.

### Check these fields in `Create an issue`

#### Connection

Should reference:

```json
"referenceName": "<github-connection-name>"
```

`github` is common, but use your actual connection name.

#### Repository path

Use the actual repository owner and repository name for your environment:

```text
/repos/@{encodeURIComponent('<owner>')}/@{encodeURIComponent('<repo>')}/issues
```

#### Suggested `title`

```text
@{concat('[SRE] ', coalesce(items('For_each')?['essentials']?['alertRule'], 'Azure Monitor alert'))}
```

#### Suggested `body`

```text
@{concat('Severity: ', coalesce(items('For_each')?['essentials']?['severity'], 'n/a'), '\nCondition: ', coalesce(items('For_each')?['essentials']?['monitorCondition'], 'n/a'), '\nFired: ', coalesce(items('For_each')?['essentials']?['firedDateTime'], 'n/a'), '\nPortal: ', coalesce(items('For_each')?['essentials']?['investigationLink'], 'n/a'))}
```

## Failure mode 4: Azure DevOps action assumes the wrong item shape

After `For each` is fixed, Azure DevOps work item creation can still fail if it uses fields like `@item()?['name']` while the foreach item is actually the alert `data` object.

### Check these fields in `Create a work item`

#### Connection

Should reference:

```json
"referenceName": "<azure-devops-connection-name>"
```

`visualstudioteamservices` is common, but use your actual connection name.

#### Suggested `title`

```text
@{concat('[SRE] ', coalesce(items('For_each')?['essentials']?['alertRule'], 'Azure Monitor alert'))}
```

#### Suggested `description`

```text
<p class=\"editor-paragraph\">Severity: @{coalesce(items('For_each')?['essentials']?['severity'], 'n/a')}</p><p class=\"editor-paragraph\">Condition: @{coalesce(items('For_each')?['essentials']?['monitorCondition'], 'n/a')}</p><p class=\"editor-paragraph\">Fired: @{coalesce(items('For_each')?['essentials']?['firedDateTime'], 'n/a')}</p><p class=\"editor-paragraph\">Portal: @{coalesce(items('For_each')?['essentials']?['investigationLink'], 'n/a')}</p>
```

#### Suggested `linkUrl`

```text
@{coalesce(items('For_each')?['essentials']?['investigationLink'], '')}
```

## Failure mode 5: Azure DevOps is blocked by GitHub failure

If `Create a work item` uses `runAfter` like this:

```json
"runAfter": {
  "Create_an_issue": [
    "Succeeded"
  ]
}
```

then Azure DevOps will not run if GitHub fails.

### Safer `runAfter`

```json
"runAfter": {
  "Create_an_issue": [
    "Succeeded",
    "Failed",
    "Skipped",
    "TimedOut"
  ]
}
```

This lets Azure DevOps proceed even if GitHub issue creation fails.

## Connector guidance

### Important

Do **not** assume connector reauthorization is required just because no ticket was created.

If the run never reaches the connector actions, the connectors are not the active failure.

### Only repair connectors when

- The run reaches `Create an issue` or `Create a work item`
- The failing action explicitly reports an authentication, authorization, or connection error
- The API Connection resource is not `Connected`

If the failure happens before the connector actions start, fix the payload handling first.

## Verification checklist

After making a fix:

1. Save the Logic App
2. Trigger a new Azure Monitor alert or resubmit the run
3. Confirm `For each` no longer fails
4. Confirm `Create an issue` runs with the expected repo and payload fields
5. Confirm `Create a work item` runs even if GitHub fails, if you changed `runAfter`
6. Verify the resulting ticket contains alert rule, severity, fired time, and portal link

## Fast triage summary

Use this order every time:

1. **Did the Logic App run at all?**
   - If no, validate the Action Group callback URL
2. **Did the run fail at `For each`?**
   - If yes, fix the payload expression before touching connectors
3. **Did the run reach GitHub / Azure DevOps?**
  - If yes, inspect the action payload fields and repository / project settings
4. **Are connectors actually disconnected?**
   - Only then reauthorize or repair them

## Customization checklist

Replace the placeholders in this skill with values from your environment:

- Logic App workflow name
- GitHub connection reference name
- Azure DevOps connection reference name
- GitHub owner and repository name
- Azure DevOps organization, project, and work item path
- Whether Azure DevOps should still run when GitHub fails

## Important takeaway

The common false lead is "the connector is broken" when the real issue is the `For each` expression or another payload-shape mismatch earlier in the run.
