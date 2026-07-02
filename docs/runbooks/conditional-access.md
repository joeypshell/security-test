# Conditional Access Runbook

Conditional Access policy changes use a report-only first model.

## Flow

1. Update JSON policy files in `identity/conditional-access/policies/`.
2. Open a PR.
3. Validate schema, defaults, and break-glass exclusions.
4. Merge to `main`.
5. Run `Deploy Entra Conditional Access` for `entra-report-only`.
6. Observe report-only impact in sign-in logs.
7. Run `Deploy Entra Conditional Access` for `entra-prod` only after approval and change ticket.

## Rules

- Policy JSON defaults to `reportOnly`.
- Policies targeting all users require break-glass exclusions.
- Production enablement requires a change ticket.
- Tenant state is exported before apply.
- `entra-prod` should require IAM, security, and change approval.
