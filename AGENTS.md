# Repository Agent Instructions

## Azure authentication scope

- Entra Conditional Access deployments are tenant-scoped Microsoft Graph operations. Authenticate each Entra GitHub Environment through its own user-assigned managed identity and GitHub OIDC federated credential.
- For Entra workflows, `AZURE_CLIENT_ID` must contain the managed identity client ID. Use it with `AZURE_TENANT_ID`, keep `allow-no-subscriptions: true`, and do not require, validate, or invent an `AZURE_SUBSCRIPTION_ID` value.
- The GitHub-hosted runner exchanges an OIDC token for the managed identity. Do not set `auth-type: IDENTITY`; that mode is for managed identities attached directly to Azure-hosted self-hosted runners.
- Subscription IDs remain required for subscription-scoped Azure Resource Manager and Bicep deployments, including the Key Vault deployment lanes.
- When Entra authentication or deployment behavior changes, update `docs/architecture/entra-managed-identity-conditional-access.md`, `docs/diagrams/entra-managed-identity-conditional-access.md`, and the affected runbook in the same change.
