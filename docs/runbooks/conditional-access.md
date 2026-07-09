# Conditional Access Runbook

Conditional Access policy changes use a report-only first model.

## Flow

1. Update JSON policy files in `identity/conditional-access/policies/`.
2. Open a PR.
3. Validate schema, defaults, and break-glass exclusions.
4. Merge to `main`.
5. Run `Deploy Entra Conditional Access` for `entra-report-only` with `mode=plan`.
6. Run `Deploy Entra Conditional Access` for `entra-report-only` with `mode=apply`.
7. Observe report-only impact in sign-in logs.
8. Run `Deploy Entra Conditional Access` for `entra-prod` only after approval and change ticket.

## Rules

- Policy JSON defaults to `reportOnly`.
- Policies targeting all users require break-glass exclusions.
- Production enablement requires a change ticket.
- Tenant state is exported before apply.
- `entra-prod` should require IAM, security, and change approval.

## Test policies

The initial test policy set is intentionally small:

- `CA001 - Require MFA for admin roles`
- `CA002 - Block legacy authentication`

Replace the placeholder user object IDs in `identity/conditional-access/required-break-glass-ids.json` before a real apply. The policy files must exclude the same emergency access accounts.

The workflow forces the deployment state from the selected environment. `entra-report-only` applies these definitions as `reportOnly`; `entra-prod` applies them as `enabled`.

Microsoft Graph stores report-only policies as `enabledForReportingButNotEnforced`. The deployment script translates the repo target `reportOnly` to that Graph state during apply.

## Deployment behavior

The workflow logs in with GitHub OIDC, obtains a Microsoft Graph token, and upserts each policy by `displayName` through `/identity/conditionalAccess/policies`.

Required GitHub Environment variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

The Entra deployment identity needs Microsoft Graph application permissions `Policy.Read.All` and `Policy.ReadWrite.ConditionalAccess` with admin consent.
