# GitHub Environments

Create these environments:

| Environment | Purpose | Suggested gate |
| --- | --- | --- |
| kv-dev | Key Vault development subscription | Optional approval |
| kv-qa | Key Vault QA subscription | Platform or security approval |
| keys-prod | Production app Key Vaults in the keys subscription | Security and change approval |
| keys-shared | Shared, departmental, or keys-only vaults in the keys subscription | Stricter security approval |
| entra-report-only | Conditional Access report-only staging | IAM or security approval |
| entra-prod | Conditional Access enablement | IAM, security, and change approval |

Each subscription-scoped Key Vault deployment environment should define:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Each Entra environment should define:

- `AZURE_CLIENT_ID`: client ID of that environment's user-assigned managed identity
- `AZURE_TENANT_ID`

Do not define `AZURE_SUBSCRIPTION_ID` for `entra-report-only` or `entra-prod`.

Use GitHub environment protection rules for reviewers, wait timers, and branch restrictions. Restrict deployments to `main` once the repository is ready for production use.

The `keys` Azure subscription should not be modeled as a single deployment environment. Use `keys-prod` for production app vaults and `keys-shared` for shared or keys-only vaults so each path can have its own approvals.
