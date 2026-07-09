# Entra Managed Identity and Conditional Access Diagrams

These diagrams accompany the detailed [architecture guide](../architecture/entra-managed-identity-conditional-access.md).

## End-to-end architecture

The upper lane is one-time identity bootstrap. The lower lane is the repeatable Conditional Access deployment path.

```mermaid
flowchart TB
    subgraph Bootstrap["One-time identity bootstrap"]
        Operator["Azure administrator"] --> ARMDeploy["Subscription-scope Bicep deployment"]
        ARMDeploy --> IdentityRG["rg-github-entra-identities"]
        IdentityRG --> ReportMI["Report-only user-assigned identity"]
        IdentityRG --> ProdMI["Production user-assigned identity"]
        ReportMI --> ReportFIC["Federated credential: entra-report-only"]
        ProdMI --> ProdFIC["Federated credential: entra-prod"]
        Operator --> PermissionScript["Grant Graph permissions script"]
        PermissionScript --> ReportRoles["Policy.Read.All and Policy.ReadWrite.ConditionalAccess"]
        PermissionScript --> ProdRoles["Policy.Read.All and Policy.ReadWrite.ConditionalAccess"]
        Operator --> EnvironmentVars["GitHub Environment variables"]
    end

    subgraph Runtime["Repeatable policy deployment"]
        Dispatch["Manual workflow dispatch"] --> EnvironmentGate{"Selected GitHub Environment"}
        EnvironmentGate -->|"entra-report-only"| ReportApproval["Report-only approval and variables"]
        EnvironmentGate -->|"entra-prod"| ProdApproval["Production approval, variables, and change ticket"]
        ReportApproval --> Runner["GitHub-hosted runner"]
        ProdApproval --> Runner
        Runner --> OIDC["GitHub OIDC token"]
        OIDC --> Entra["Entra token endpoint validates federated claims"]
        ReportFIC -. "trust rule" .-> Entra
        ProdFIC -. "trust rule" .-> Entra
        Entra --> GraphToken["Short-lived Microsoft Graph token"]
        ReportRoles -. "roles claim" .-> GraphToken
        ProdRoles -. "roles claim" .-> GraphToken
        GraphToken --> Deployment["Validate, plan, export, and upsert"]
        Deployment --> GraphAPI["Microsoft Graph Conditional Access API"]
    end
```

## OIDC authentication sequence

The subscription hosts the managed identity but is not part of the tenant-scoped runtime token exchange.

```mermaid
sequenceDiagram
    actor Operator
    participant Actions as GitHub Actions
    participant OIDC as GitHub OIDC provider
    participant Entra as Microsoft Entra ID
    participant CLI as Azure Login and Azure CLI
    participant Script as PowerShell deployment
    participant Graph as Microsoft Graph

    Operator->>Actions: Select target, mode, and change ticket
    Actions->>Actions: Apply GitHub Environment approvals
    Actions->>OIDC: Request job OIDC token
    OIDC-->>Actions: Signed short-lived token
    Actions->>Entra: Exchange token using managed identity client ID and tenant ID
    Entra->>Entra: Verify issuer, audience, and environment subject
    Entra-->>CLI: Establish federated identity session
    CLI->>Entra: Request token for https://graph.microsoft.com
    Entra-->>CLI: Graph token containing assigned application roles
    Script->>CLI: Read Graph access token
    Script->>Graph: GET existing Conditional Access policies
    Graph-->>Script: Existing policy collection
    alt Policy display name exists once
        Script->>Graph: PATCH existing policy
    else Policy display name does not exist
        Script->>Graph: POST new policy
    else Display name exists more than once
        Script-->>Actions: Stop with ambiguity error
    end
```

## Environment and trust isolation

Each GitHub Environment has a distinct federated subject and managed identity.

```mermaid
flowchart LR
    subgraph GitHub["GitHub trust boundary"]
        ReportEnv["Environment: entra-report-only"]
        ProdEnv["Environment: entra-prod"]
    end

    subgraph EntraID["Microsoft Entra trust boundary"]
        ReportSubject["Subject: repo:joeypshell/security-test:environment:entra-report-only"]
        ProdSubject["Subject: repo:joeypshell/security-test:environment:entra-prod"]
        ReportIdentity["gh-secdept-entra-ca-reportonly"]
        ProdIdentity["gh-secdept-entra-ca-prod"]
    end

    subgraph Graph["Microsoft Graph authorization boundary"]
        ReportPermissions["Report-only identity app roles"]
        ProdPermissions["Production identity app roles"]
        ConditionalAccess["Conditional Access policies"]
    end

    ReportEnv --> ReportSubject --> ReportIdentity --> ReportPermissions --> ConditionalAccess
    ProdEnv --> ProdSubject --> ProdIdentity --> ProdPermissions --> ConditionalAccess
    ReportEnv -. "cannot satisfy" .-> ProdSubject
    ProdEnv -. "cannot satisfy" .-> ReportSubject
```

## Policy deployment decision flow

```mermaid
flowchart TD
    Start["Workflow dispatch"] --> Target{"Target environment"}
    Target -->|"entra-report-only"| ReportState["Force reportOnly"]
    Target -->|"entra-prod"| Ticket{"Change ticket provided?"}
    Ticket -->|"No"| StopTicket["Stop before authentication"]
    Ticket -->|"Yes"| EnabledState["Force enabled"]
    ReportState --> Login["Federated Azure Login"]
    EnabledState --> Login
    Login --> Validate["Validate JSON and break-glass exclusions"]
    Validate -->|"Failure"| StopValidation["Report all validation failures"]
    Validate -->|"Success"| Plan["Print planned upserts"]
    Plan --> Mode{"Mode"}
    Mode -->|"plan"| EndPlan["Finish without Graph write"]
    Mode -->|"apply"| Export["Request Graph token and export current tenant policies"]
    Export --> Existing["Read existing policies for deployment"]
    Existing --> Match{"Exact displayName matches"}
    Match -->|"0"| Create["POST new policy"]
    Match -->|"1"| Update["PATCH existing policy"]
    Match -->|">1"| StopDuplicate["Stop: ambiguous tenant state"]
    Create --> Complete["Record created policy ID"]
    Update --> Complete
```

## State translation

```mermaid
flowchart LR
    ReportEnv["entra-report-only"] --> RepoReport["Repository target: reportOnly"] --> GraphReport["Graph state: enabledForReportingButNotEnforced"]
    ProdEnv["entra-prod"] --> RepoEnabled["Repository target: enabled"] --> GraphEnabled["Graph state: enabled"]
```
