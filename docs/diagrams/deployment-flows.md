# Deployment Flows

This diagram shows the end-to-end flow from branch to deployment lane.

See `entra-managed-identity-conditional-access.md` for the detailed Conditional Access identity, token, trust, and upsert flows.

```mermaid
flowchart TD
    A["Feature branch"] --> B["Pull Request"]

    B --> C["PR validation"]
    C --> C1["Bicep build"]
    C --> C2["PowerShell and script checks"]
    C --> C3["Custom security policy checks"]
    C --> C4["Secret scanning"]
    C --> C5["What-if where available"]

    C --> D{"Approved and checks pass?"}
    D -- "No" --> B
    D -- "Yes" --> E["Merge to protected main"]

    E --> F{"Deployment lane"}

    F --> G["Key Vault deployments"]
    F --> H["Policy deployments"]
    F --> I["NSG / WAF deployments"]
    F --> J["Conditional Access deployments"]

    G --> K{"Key Vault type"}

    K --> L["App lifecycle vault"]
    L --> L1["Deploy to kv-dev"]
    L1 --> L2["Deploy to kv-qa"]
    L2 --> L3["Approve deploy to keys-prod"]
    L3 --> L4["Deploy production app vaults in keys subscription"]

    K --> M["Keys-only / shared vault"]
    M --> M1["What-if keys-shared"]
    M1 --> M2["Stricter approval"]
    M2 --> M3["Deploy shared, security, or departmental vaults in keys subscription"]

    H --> H1["Policy validation / what-if"]
    H1 --> H2["Approval"]
    H2 --> H3["Deploy policy"]

    I --> I1["Network rule validation"]
    I1 --> I2["Approval"]
    I2 --> I3["Deploy NSG / WAF rules"]

    J --> J0["GitHub OIDC to environment managed identity"]
    J0 --> J1["Validate Conditional Access JSON"]
    J1 --> J2["Deploy report-only"]
    J2 --> J3["Observe impact"]
    J3 --> J4["Approve enablement"]
    J4 --> J5["Enable Conditional Access policy"]
```
