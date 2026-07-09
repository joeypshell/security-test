# security-test

This repository is a test structure for security infrastructure automation. It uses one protected `main` branch, short-lived feature branches, and GitHub Environments as the deployment and approval boundary.

## Operating model

Branches represent code maturity:

- `main`
- `feature/*`
- `hotfix/*`

Environments represent deployment targets and approval boundaries:

- `kv-dev`
- `kv-qa`
- `keys-prod`
- `keys-shared`
- `entra-report-only`
- `entra-prod`

The same commit should move through environments with increasing approvals. Do not create long-lived `dev`, `qa`, `prod`, or `keys` branches.

The `keys` Azure subscription is intentionally split into two GitHub deployment targets:

- `keys-prod` for production app Key Vaults that promote through `kv-dev` and `kv-qa`
- `keys-shared` for departmental, security, or keys-only vaults that do not have dev/qa/prod copies

## Repository layout

```text
.github/
  workflows/          GitHub Actions validation and deployment workflows
  CODEOWNERS          Path-based review ownership
infra/
  modules/            Reusable Bicep modules
  stacks/             Deployable Bicep stacks with target parameter files
identity/
  conditional-access/ Conditional Access policy definitions and tests
scripts/
  validation/         Local and CI validation gates
  operational/        Deployment and operational entrypoints
  migration/          Migration helpers
  reporting/          Export and reporting helpers
docs/
  diagrams/           Mermaid diagrams for deployment flow and target mapping
  adr/                Architecture decisions
  runbooks/           Setup and operating runbooks
```

## Pull request validation

PRs run:

- Bicep build for templates and parameter files
- repository policy checks for dangerous infra patterns
- Conditional Access policy validation
- PowerShell ScriptAnalyzer
- secret scanning with Gitleaks
- dependency review

## Deployment

Key Vault deployments use `.github/workflows/deploy-keyvault.yml`.

Required GitHub Environment variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

The workflow authenticates with Azure using OIDC, runs `what-if`, then deploys only when the operator selects `deploy`.

Key Vault examples:

- app lifecycle vault: `sample-app` to `kv-dev`, then `kv-qa`, then `keys-prod`
- keys-only vault: `department-shared` to `keys-shared`

Conditional Access changes use `.github/workflows/deploy-entra.yml` and the local `.github/actions/deploy-conditional-access` action. Each Entra environment authenticates through GitHub OIDC as its own user-assigned managed identity. Entra deployment requires `AZURE_CLIENT_ID` and `AZURE_TENANT_ID`, but not `AZURE_SUBSCRIPTION_ID`. Policies default to `reportOnly`; production enablement is separated behind the `entra-prod` environment and requires a change ticket. The initial test set contains `CA001 - Require MFA for admin roles` and `CA002 - Block legacy authentication`.

See `docs/diagrams/deployment-flows.md` for the full flow.

## Local validation

Run this before opening a PR:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validation/Invoke-LocalValidation.ps1
```

Some checks are skipped locally if optional tools such as Azure CLI, Bicep, or PSScriptAnalyzer are not installed.
