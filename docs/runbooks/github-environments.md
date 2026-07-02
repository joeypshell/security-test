# GitHub Environments

Create these environments:

| Environment | Purpose | Suggested gate |
| --- | --- | --- |
| sandbox | Low-risk validation target | Optional approval |
| dev | Shared development subscription | Optional approval |
| qa | Pre-production validation | Platform or security approval |
| prod | Production resource deployment | Security and change approval |
| keys-prod | Key management boundary | Stricter security approval |
| entra-report-only | Conditional Access report-only staging | IAM or security approval |
| entra-prod | Conditional Access enablement | IAM, security, and change approval |

Each Azure deployment environment should define:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Use GitHub environment protection rules for reviewers, wait timers, and branch restrictions. Restrict deployments to `main` once the repository is ready for production use.
