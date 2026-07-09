# Azure OIDC Setup

Use GitHub OIDC instead of stored Azure client secrets. Entra Conditional Access deployments authenticate as user-assigned managed identities; they do not use app registrations or client secrets.

Create one Azure identity per blast radius:

```text
gh-secdept-kv-dev-deploy
gh-secdept-kv-qa-deploy
gh-secdept-keys-prod-deploy
gh-secdept-keys-shared-deploy
gh-secdept-entra-ca-reportonly
gh-secdept-entra-ca-prod
```

Do not reuse one highly privileged identity across all environments.

## Entra managed identities

Provision the `entra-report-only` and `entra-prod` identities with `infra/stacks/entra-identities/main.bicep`. This is a one-time Azure Resource Manager deployment, so the operator provisioning the identities must select the subscription and resource group that will host them:

```powershell
az login
az account set --subscription <identity-hosting-subscription-id>
az deployment sub create `
  --name github-entra-managed-identities `
  --location centralus `
  --parameters infra/stacks/entra-identities/params/security-test.bicepparam
```

The template creates one user-assigned managed identity per GitHub Environment. Each federated credential trusts only its matching subject:

```text
repo:joeypshell/security-test:environment:entra-report-only
repo:joeypshell/security-test:environment:entra-prod
```

Grant the required Microsoft Graph application permissions to both managed identities. This requires an interactive administrator with Privileged Role Administrator and the Microsoft Entra PowerShell module:

```powershell
Install-Module Microsoft.Entra -Scope CurrentUser

.\scripts\operational\Grant-ManagedIdentityGraphPermissions.ps1 `
  -TenantId <tenant-id> `
  -ManagedIdentityClientId @(
    '<entra-report-only-managed-identity-client-id>',
    '<entra-prod-managed-identity-client-id>'
  )
```

Set these GitHub Environment variables separately in `entra-report-only` and `entra-prod`:

- `AZURE_CLIENT_ID`: client ID of that environment's user-assigned managed identity
- `AZURE_TENANT_ID`: Microsoft Entra tenant ID

Do not define `AZURE_SUBSCRIPTION_ID` for either Entra environment. The workflow exchanges the GitHub OIDC token for the managed identity and requests a Microsoft Graph token at tenant scope with `allow-no-subscriptions: true`.

The subscription is required only to create and host the managed identities. It is not used by Conditional Access deployment runs.

## Subscription-scoped deployment identities

For the Key Vault identities:

1. Create a user-assigned managed identity pattern approved by your organization.
2. Add a federated credential for this repository and the matching GitHub Environment.
3. Assign only the Azure roles needed for that target scope.
4. Store the client ID, tenant ID, and subscription ID as GitHub Environment variables.

## Conditional Access Graph permissions

The `entra-report-only` and `entra-prod` managed identities deploy tenant-scoped Conditional Access policies through Microsoft Graph, not Azure Resource Manager. Grant only these Microsoft Graph application permissions:

- `Policy.Read.All`
- `Policy.ReadWrite.ConditionalAccess`

Do not grant these Graph permissions to the Key Vault deployment identities.
