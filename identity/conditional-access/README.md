# Conditional Access

Conditional Access policy definitions live in `policies/` as JSON. The repo treats them differently from Azure resource deployments because most tenants do not have a realistic Conditional Access sandbox.

Required controls:

- every policy change goes through PR review
- policies default to `reportOnly`
- break-glass accounts are excluded
- emergency access exclusions are validated by ID
- production enablement requires the `entra-prod` GitHub Environment
- production enablement requires a change ticket
- current tenant state is exported before apply

Use `entra-report-only` first, observe sign-in impact, then promote through `entra-prod` after approval.
