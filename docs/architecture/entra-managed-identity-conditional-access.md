# Entra Managed Identity Conditional Access Architecture

## Purpose

This document explains how this repository provisions GitHub deployment identities, authenticates GitHub Actions without client secrets, obtains Microsoft Graph tokens, and deploys Conditional Access policies.

The complete diagram set is in [`docs/diagrams/entra-managed-identity-conditional-access.md`](../diagrams/entra-managed-identity-conditional-access.md).

## Core design

The design separates identity bootstrap from normal policy deployment:

1. A one-time Azure Resource Manager deployment creates user-assigned managed identities and GitHub federated credentials.
2. A privileged administrator grants the managed identities the required Microsoft Graph application permissions.
3. GitHub Environment variables connect each deployment environment to its dedicated managed identity.
4. Every normal workflow run uses a short-lived GitHub OIDC token to authenticate as that identity.
5. PowerShell obtains a Microsoft Graph token and creates or updates Conditional Access policies.

The managed identity is an Azure resource and therefore must be hosted in an Azure subscription. Normal Conditional Access deployment does not use that subscription because Conditional Access and Microsoft Graph are tenant-scoped.

## Components

| Component | Responsibility |
| --- | --- |
| `infra/stacks/entra-identities/main.bicep` | Creates the identity resource group and separate report-only and production identities. |
| `infra/modules/github-federated-managed-identity/main.bicep` | Creates one user-assigned identity and one environment-scoped GitHub federated credential. |
| `scripts/operational/Grant-ManagedIdentityGraphPermissions.ps1` | Grants the two Microsoft Graph application permissions required by this deployment. |
| GitHub Environment `entra-report-only` | Holds the report-only identity client ID and approval policy. |
| GitHub Environment `entra-prod` | Holds the production identity client ID and stricter approval policy. |
| `.github/workflows/deploy-entra.yml` | Selects the environment, authenticates with OIDC, exports tenant state, and invokes the deployment action. |
| `.github/actions/deploy-conditional-access/action.yml` | Validates, plans, and conditionally applies policy changes. |
| `scripts/shared/GraphAccess.ps1` | Obtains Graph access tokens and provides Graph REST helpers. |
| `scripts/operational/Invoke-ConditionalAccessDeployment.ps1` | Converts repository policy definitions into create or update requests. |
| `scripts/reporting/Export-TenantState.ps1` | Captures the current tenant policy state before an apply operation. |
| `identity/conditional-access/tests/Test-ConditionalAccessPolicy.ps1` | Enforces report-only defaults and emergency-access exclusions. |

## Phase 1: identity bootstrap

Identity bootstrap is performed once per environment or whenever an identity must be replaced.

### 1. Select the hosting subscription

The user-assigned managed identities must be created inside an Azure subscription and resource group:

```powershell
az login
az account set --subscription <identity-hosting-subscription-id>
```

This subscription hosts the identity resources. It does not become the deployment target for Conditional Access.

### 2. Deploy the identity stack

```powershell
az deployment sub create `
  --name github-entra-managed-identities `
  --location centralus `
  --parameters infra/stacks/entra-identities/params/security-test.bicepparam
```

The stack creates:

| GitHub Environment | Managed identity | Federated subject |
| --- | --- | --- |
| `entra-report-only` | `gh-secdept-entra-ca-reportonly` | `repo:joeypshell/security-test:environment:entra-report-only` |
| `entra-prod` | `gh-secdept-entra-ca-prod` | `repo:joeypshell/security-test:environment:entra-prod` |

The Bicep outputs include each identity's client ID, principal ID, tenant ID, name, and federated subject.

### 3. Understand the federated credential

The federated credential is a trust rule, not a stored secret. Entra accepts a GitHub token only when these claims match:

| Claim | Required value |
| --- | --- |
| Issuer | `https://token.actions.githubusercontent.com` |
| Audience | `api://AzureADTokenExchange` |
| Subject | Exact repository and GitHub Environment subject shown above |

The subject prevents the report-only environment from using the production identity and prevents another repository from using either identity.

### 4. Grant Graph application permissions

Creating a managed identity does not grant Microsoft Graph permissions. A Privileged Role Administrator runs:

```powershell
Install-Module Microsoft.Entra -Scope CurrentUser

.\scripts\operational\Grant-ManagedIdentityGraphPermissions.ps1 `
  -TenantId <tenant-id> `
  -ManagedIdentityClientId @(
    '<entra-report-only-client-id>',
    '<entra-prod-client-id>'
  )
```

The script grants only:

- `Policy.Read.All`
- `Policy.ReadWrite.ConditionalAccess`

The script checks existing app-role assignments first, so running it again does not intentionally create duplicate assignments.

### 5. Configure GitHub Environments

Set these variables independently in `entra-report-only` and `entra-prod`:

| Variable | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | Client ID of the managed identity dedicated to that GitHub Environment. |
| `AZURE_TENANT_ID` | Entra tenant ID containing the managed identity and Conditional Access policies. |

Do not define `AZURE_SUBSCRIPTION_ID` for the Entra environments. The workflow uses `allow-no-subscriptions: true` because it calls Microsoft Graph rather than Azure Resource Manager.

Recommended protection rules:

| Environment | Recommended protection |
| --- | --- |
| `entra-report-only` | IAM or security reviewer. |
| `entra-prod` | IAM, security, and change approval; restrict deployment to `main`. |

## Phase 2: runtime authentication

### 1. Operator dispatches the workflow

The operator selects:

| Input | Meaning |
| --- | --- |
| `target` | Selects `entra-report-only` or `entra-prod`, including that environment's variables and approval rules. |
| `mode` | `plan` prints the intended upserts; `apply` changes Microsoft Graph. |
| `change_ticket` | Required when the target is `entra-prod`. |

### 2. GitHub issues an OIDC token

The workflow grants `id-token: write`. This permission allows the job to request a short-lived signed token from GitHub's OIDC provider. It does not grant write access to repository contents.

The token contains claims identifying the repository, workflow context, and selected GitHub Environment.

### 3. Azure Login exchanges the token

`azure/login` sends the following to the tenant's Entra token endpoint:

- the GitHub OIDC token
- the managed identity client ID from `AZURE_CLIENT_ID`
- the tenant ID from `AZURE_TENANT_ID`

Entra locates the managed identity service principal by client ID and verifies the OIDC token against the identity's federated credential. If issuer, audience, or subject does not match, login fails.

The workflow runs on a GitHub-hosted runner. It intentionally does not set `auth-type: IDENTITY`; that mode is for a managed identity attached directly to an Azure-hosted self-hosted runner. Here, the runner uses OIDC federation.

### 4. Azure CLI establishes the identity context

After a successful exchange, Azure Login configures the Azure CLI session as the managed identity. No client secret, certificate, or long-lived GitHub credential is present.

Because `allow-no-subscriptions: true` is enabled, Azure Login does not require a default subscription.

### 5. PowerShell requests a Graph token

`Get-GraphAccessToken` executes:

```powershell
az account get-access-token `
  --resource https://graph.microsoft.com `
  --query accessToken `
  --output tsv
```

Entra issues a Microsoft Graph access token for the managed identity. The token includes the application roles assigned during bootstrap.

## Policy deployment pipeline

### Policy files

Deployable definitions are the standard JSON files under `identity/conditional-access/policies/`. Standard JSON does not support comments, so these files intentionally remain uncommented. Their important fields are documented here instead:

| Field | Purpose |
| --- | --- |
| `displayName` | Stable exact-match key used to decide whether Graph receives `POST` or `PATCH`. |
| `state` | Must remain `reportOnly` in source control; the workflow overrides it from the selected environment. |
| `conditions.users.includeUsers` | User scope; the value `All` triggers an explicit exclusion requirement. |
| `conditions.users.excludeUsers` | Emergency-access accounts that must remain outside policy enforcement. |
| `conditions.clientAppTypes` | Client application types included by the policy, such as legacy authentication clients. |
| `grantControls` | Access decision, such as blocking access or requiring MFA. |

`identity/conditional-access/required-break-glass-ids.json` is also standard JSON and therefore cannot contain comments. Its `excludeUsers` array is the central list enforced against every policy by validation.

### Environment-to-state mapping

The workflow owns the target state. Policy files cannot choose production enablement during a normal deployment.

| GitHub Environment | Repository state | Microsoft Graph state |
| --- | --- | --- |
| `entra-report-only` | `reportOnly` | `enabledForReportingButNotEnforced` |
| `entra-prod` | `enabled` | `enabled` |

### Validation

Before any apply, the composite action runs `Test-ConditionalAccessPolicy.ps1`. It checks:

- every policy file is valid JSON
- every policy has a display name
- repository policy state defaults to `reportOnly`
- all configured emergency-access account IDs are excluded
- policies targeting all users have exclusions

Validation collects all policy failures and reports them together.

### Plan

The plan step always runs. It loads the policy files, applies the environment-selected target state in memory, removes Graph read-only properties, and prints the intended upserts.

Plan mode returns before requesting a Microsoft Graph token or making a Graph REST request.

### Pre-change export

Apply mode exports the tenant's existing Conditional Access policies to `tenant-state-export.json`. GitHub uploads that file as a workflow artifact before the deployment step runs.

This export is a review and recovery aid. The workflow does not automatically roll back from it.

### Apply and upsert

Apply mode retrieves existing policies with:

```text
GET /v1.0/identity/conditionalAccess/policies
```

Each repository policy is matched by exact `displayName`:

- no match -> `POST` creates the policy
- one match -> `PATCH` updates the policy
- multiple matches -> deployment stops because selecting one would be ambiguous

The deployment sends the complete repository policy body after removing Graph-managed fields such as `id`, `createdDateTime`, and `modifiedDateTime`.

## Security boundaries

### Separate identities

Report-only and production use separate user-assigned identities. This allows different GitHub approvals, audit trails, and future permission changes without sharing one deployment principal.

### No stored credential

GitHub stores identifiers, not credentials. `AZURE_CLIENT_ID` and `AZURE_TENANT_ID` are not passwords. The usable credential is a short-lived OIDC token created only for the current job.

### Exact federated subjects

Each identity trusts one exact GitHub Environment subject. A token for a branch-only subject or a different environment does not satisfy the trust rule.

### Least-privilege Graph roles

The deployment identities receive only the Graph application roles needed to read and modify Conditional Access. They do not receive Azure subscription RBAC through this stack.

### Emergency-access validation

Required emergency-access object IDs live in `identity/conditional-access/required-break-glass-ids.json`. Every policy must exclude those IDs before validation succeeds.

### Production controls

Production requires all of the following:

- merge to protected `main`
- `entra-prod` environment approval
- a non-empty change ticket
- policy validation
- a pre-change tenant export

## Failure modes

| Failure | Likely cause | Check |
| --- | --- | --- |
| Azure Login reports no matching federated identity | Repository, environment, issuer, or audience does not match the federated credential. | Compare the Bicep federated subject with the selected GitHub Environment. |
| Azure Login requests a subscription | `allow-no-subscriptions` is missing or false. | Inspect `.github/workflows/deploy-entra.yml`. |
| Graph returns `AccessDenied` | Managed identity is missing a required Graph app role or tenant licensing blocks Conditional Access. | Review app-role assignments and tenant licensing. |
| Graph returns a schema error | Repository JSON contains an unsupported property or state value. | Run local validation and inspect the generated request body. |
| Production run stops before login | Change ticket is empty. | Supply `change_ticket` when selecting `entra-prod`. |
| Validation reports a missing break-glass exclusion | Policy does not exclude every required emergency-access ID. | Compare the policy with `required-break-glass-ids.json`. |
| Deployment finds multiple policies with one display name | Tenant contains duplicate policy display names. | Resolve the duplicate manually before rerunning. |
| Plan succeeds but tenant does not change | `mode=plan` was selected. | Rerun with `mode=apply` after approval. |

## Verification

### Local repository validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\validation\Invoke-LocalValidation.ps1
```

### Inspect managed identity outputs

```powershell
az deployment sub show `
  --name github-entra-managed-identities `
  --query properties.outputs
```

### Verify Graph permissions

Run the permission script with `-WhatIf` to verify identity and role discovery without creating assignments:

```powershell
.\scripts\operational\Grant-ManagedIdentityGraphPermissions.ps1 `
  -TenantId <tenant-id> `
  -ManagedIdentityClientId @('<report-only-client-id>', '<production-client-id>') `
  -WhatIf
```

### Validate deployment progressively

1. Run `entra-report-only` with `mode=plan`.
2. Review the planned policy names and state.
3. Run `entra-report-only` with `mode=apply`.
4. Confirm both policies appear as report-only in Entra.
5. Review sign-in logs and report-only impact.
6. Use `entra-prod` only after approval and a change ticket.

## What this automation does not do

- It does not create managed identities during a Conditional Access workflow run.
- It does not automatically grant Graph permissions during normal deployment.
- It does not store or rotate client secrets because none are used.
- It does not automatically promote report-only policies after an observation period.
- It does not automatically roll back from the exported tenant snapshot.
- It does not manage Conditional Access licensing.
- It does not delete tenant policies that are absent from the repository.

These exclusions are intentional. Identity bootstrap and privileged permission grants remain explicit administrative actions, while normal policy deployment stays repeatable and narrowly scoped.
