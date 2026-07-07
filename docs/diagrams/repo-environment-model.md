# Repository and Environment Model

This diagram separates code organization from deployment control. The repo stores the source of truth, workflows route changes by control area, and GitHub Environments hold Azure target configuration and approval gates.

```mermaid
flowchart LR
    R["security-test repo"] --> F["Folders"]
    R --> W["Workflows"]
    R --> D["Docs and runbooks"]

    F --> FK["infra/stacks/keyvault"]
    F --> FN["infra/stacks/network-security"]
    F --> FW["infra/stacks/waf"]
    F --> FP["infra/stacks/azure-policy"]
    F --> FI["identity/conditional-access"]

    W --> WK["deploy-keyvault.yml"]
    W --> WV["validate.yml"]
    W --> WN["planned: deploy-network-security.yml"]
    W --> WW["planned: deploy-waf.yml"]
    W --> WP["planned: deploy-azure-policy.yml"]

    WK --> EKD["kv-dev"]
    WK --> EKP["keys-prod"]
    WK --> EKS["keys-shared"]

    WN --> END["network-dev"]
    WN --> ENP["network-prod"]

    WW --> EWD["waf-dev"]
    WW --> EWP["waf-prod"]

    WP --> EPD["policy-dev"]
    WP --> EPP["policy-prod"]

    FI --> ERO["entra-report-only"]
    FI --> EPR["entra-prod"]

    EKD --> AKD["Sandbox Azure identity and subscription"]
    EKP --> AKP["Production Azure identity and subscription"]
    EKS --> AKS["Shared keys Azure identity and subscription"]

    ENP --> ANP["Production network scope"]
    EWP --> AWP["Production WAF scope"]
    EPP --> APP["Production policy scope"]
    EPR --> AEP["Production tenant controls"]
```

## Design rule

Branches should not represent Azure environments. Use branches for review state and use GitHub Environments for deployment state.
