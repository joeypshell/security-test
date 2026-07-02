# Azure OIDC Setup

Use GitHub OIDC instead of stored Azure client secrets.

Create one Azure identity per blast radius:

```text
gh-secdept-sandbox-deploy
gh-secdept-dev-deploy
gh-secdept-qa-deploy
gh-secdept-prod-deploy
gh-secdept-keys-prod-deploy
gh-secdept-entra-ca-reportonly
gh-secdept-entra-ca-prod
```

For each identity:

1. Create an app registration or user-assigned managed identity pattern approved by your organization.
2. Add a federated credential for this repository and the matching GitHub Environment.
3. Assign only the Azure roles needed for that target scope.
4. Store the client ID, tenant ID, and subscription ID as GitHub Environment variables.

Do not reuse one highly privileged identity across all environments.
