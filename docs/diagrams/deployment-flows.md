# Deployment Flows

This diagram shows how a reviewed commit moves from feature work into Bicep deployment lanes. Branches carry code review state; GitHub Environments carry Azure target, identity, and approval state.

```mermaid
flowchart TD
    A["Short-lived feature branch"] --> B["Pull request into main"]

    B --> C["PR validation"]
    C --> C1["Bicep build"]
    C --> C2["PowerShell and script checks"]
    C --> C3["Repository policy checks"]
    C --> C4["Secret scanning"]
    C --> C5["Path and parameter validation"]

    C --> D{"Approved and checks pass?"}
    D -- "No" --> B
    D -- "Yes" --> E["Merge to protected main"]

    E --> F{"Changed deployment lane"}

    F --> G["Key Vault"]
    F --> H["Azure Policy"]
    F --> I["NSG / network security"]
    F --> J["WAF"]
    F --> K["Conditional Access"]

    G --> G1{"Key Vault deployment class"}
    G1 --> G2["App lifecycle vault"]
    G2 --> G3["Auto deploy to kv-dev"]
    G3 --> G4["Optional deploy to kv-qa"]
    G4 --> G5["Manual approval on keys-prod"]
    G5 --> G6["Deploy production app vaults"]

    G1 --> G7["Keys-only / shared vault"]
    G7 --> G8["What-if keys-shared"]
    G8 --> G9["Manual approval on keys-shared"]
    G9 --> G10["Deploy shared or departmental vaults"]

    H --> H1["Validate policy definitions and assignments"]
    H1 --> H2["Deploy to policy-dev"]
    H2 --> H3["Manual approval on policy-prod"]
    H3 --> H4["Assign production policy"]

    I --> I1["Validate network rules"]
    I1 --> I2["Deploy to network-dev"]
    I2 --> I3["Manual approval on network-prod"]
    I3 --> I4["Deploy production NSG rules"]

    J --> J1["Validate WAF policy"]
    J1 --> J2["Deploy to waf-dev"]
    J2 --> J3["Manual approval on waf-prod"]
    J3 --> J4["Deploy production WAF policy"]

    K --> K1["Validate Conditional Access definitions"]
    K1 --> K2["Deploy report-only"]
    K2 --> K3["Observe impact"]
    K3 --> K4["Manual approval on entra-prod"]
    K4 --> K5["Enable production policy"]
```
