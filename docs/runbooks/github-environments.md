# GitHub Environments Runbook

This runbook describes how to configure GitHub Environments for Bicep-based Azure deployments in this repo.

## Required environments

Start with these Key Vault environments:

| Environment | Purpose | Approval |
| --- | --- | --- |
| `kv-dev` | Sandbox Key Vault deployment after merge to `main` | No required reviewer for the test repo |
| `kv-qa` | Optional middle validation target | Optional reviewer |
| `keys-prod` | Production app Key Vault deployment | Required reviewer |
| `keys-shared` | Shared, security, or departmental Key Vaults | Required reviewer |

Planned environments:

| Environment | Purpose |
| --- | --- |
| `network-dev` | Lower NSG and network security validation |
| `network-prod` | Production NSG and network security deployment |
| `waf-dev` | Lower WAF policy validation |
| `waf-prod` | Production WAF policy deployment |
| `policy-dev` | Lower Azure Policy assignment validation |
| `policy-prod` | Production Azure Policy assignment |
| `entra-report-only` | Conditional Access report-only deployment |
| `entra-prod` | Conditional Access production enablement |

## Environment variables

Each Azure deployment environment needs these GitHub Environment variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

The Key Vault workflow reads these from the `vars` context.

## Recommended protection rules

### Lower environments

Use this for `kv-dev`, `network-dev`, `waf-dev`, and `policy-dev`:

- Required reviewers: off for this test repo
- Deployment branches: selected branches only, `main`
- Environment variables: lower Azure deployment identity and subscription

### Production environments

Use this for `keys-prod`, `keys-shared`, `network-prod`, `waf-prod`, `policy-prod`, and `entra-prod`:

- Required reviewers: on
- Prevent self-review: on when another reviewer exists
- Deployment branches: selected branches only, `main`
- Admin bypass: disable for a real governed repo
- Environment variables: production Azure deployment identity and subscription

## Azure OIDC subject examples

Use a separate Azure federated credential per GitHub Environment.

| GitHub Environment | Federated credential subject |
| --- | --- |
| `kv-dev` | `repo:joeypshell/security-test:environment:kv-dev` |
| `keys-prod` | `repo:joeypshell/security-test:environment:keys-prod` |
| `keys-shared` | `repo:joeypshell/security-test:environment:keys-shared` |
| `network-prod` | `repo:joeypshell/security-test:environment:network-prod` |
| `policy-prod` | `repo:joeypshell/security-test:environment:policy-prod` |

Do not reuse the same Azure identity across lower and production environments unless this is a disposable lab.

## Setup checklist

1. Go to repository settings.
2. Open Environments.
3. Create each environment using the exact names in this runbook.
4. Add environment variables for the matching Azure identity and subscription.
5. Add required reviewers for production environments.
6. Restrict production environments to deployments from `main`.
7. Configure Azure federated credentials using the matching environment subject.
8. Assign only the minimum Azure roles needed for the deployment lane.
9. Open a PR and confirm validation runs before merge.
10. Merge to `main` and confirm lower deployment starts before production approval.

## Naming caution

Keep environment names exact. A typo in a workflow environment name can create or target the wrong environment configuration.
