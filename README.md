# security-test

This repository is a mock security infrastructure automation repo. It uses Bicep-only deployments, one protected `main` branch, short-lived feature branches, and GitHub Environments as the deployment and approval boundary.

## Operating model

Branches represent code maturity:

- `main`
- `feature/*`
- `hotfix/*`
- `agent/*`

Environments represent deployment targets, Azure identities, subscription scope, and approval boundaries:

- `kv-dev`
- `kv-qa`
- `keys-prod`
- `keys-shared`
- `network-dev`
- `network-prod`
- `waf-dev`
- `waf-prod`
- `policy-dev`
- `policy-prod`
- `entra-report-only`
- `entra-prod`

The same reviewed commit should move through environments with increasing approval. Do not create long-lived `dev`, `qa`, `prod`, `network`, or `keys` branches.

## Repository model

Use one repo for security infrastructure, separated by folders and workflows rather than by resource-type repos.

| Layer | Purpose |
| --- | --- |
| Repo | Security infrastructure source of truth |
| Folder | Control area such as Key Vault, network security, WAF, or policy |
| Workflow | Deployment lane for a control area |
| Environment | Azure target, identity, and approval gate |
| Branch | Short-lived code review flow |

## Deployment lanes

| Lane | Sandbox / lower environment | Production environment | Workflow |
| --- | --- | --- | --- |
| Key Vault | `kv-dev`, optional `kv-qa` | `keys-prod`, `keys-shared` | `.github/workflows/deploy-keyvault.yml` |
| NSG / network security | `network-dev` | `network-prod` | planned |
| WAF | `waf-dev` | `waf-prod` | planned |
| Azure Policy | `policy-dev` | `policy-prod` | planned |
| Conditional Access | `entra-report-only` | `entra-prod` | planned |

The `keys` Azure subscription is intentionally split into two GitHub deployment targets:

- `keys-prod` for production app Key Vaults that promote through `kv-dev` and optional `kv-qa`
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

PRs should run:

- Bicep build for templates
- parameter file path checks
- repository policy checks for dangerous infrastructure patterns
- PowerShell ScriptAnalyzer where available
- secret scanning
- dependency review where applicable

## Deployment

Key Vault deployments use `.github/workflows/deploy-keyvault.yml`.

Required GitHub Environment variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

The workflow authenticates with Azure using OIDC, runs `what-if`, and deploys with Bicep. Sandbox Key Vault deployment can run automatically after merge to `main`; production deployment is gated by GitHub Environment approval.

Key Vault examples:

- app lifecycle vault: `sample-app` to `kv-dev`, optionally `kv-qa`, then `keys-prod`
- keys-only vault: `department-shared` to `keys-shared`

## Documentation

- `docs/diagrams/deployment-flows.md`
- `docs/diagrams/repo-environment-model.md`
- `docs/runbooks/github-environments.md`
- `docs/adr/0001-one-repo-environment-based-deployments.md`

## Local validation

Run this before opening a PR:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validation/Invoke-LocalValidation.ps1
```

Some checks are skipped locally if optional tools such as Azure CLI, Bicep, or PSScriptAnalyzer are not installed.
