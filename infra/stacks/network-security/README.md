# Network Security Stack

Placeholder for NSG and related network security deployment stacks.

## Intended model

- Lower target: `network-dev`
- Production target: `network-prod`
- Deployment method: Bicep
- Workflow: planned `.github/workflows/deploy-network-security.yml`

## Guardrails to add before deployment

- Reject broad inbound rules unless an exception is documented.
- Require named rule owners and expiration where appropriate.
- Prefer application or subnet-scoped rules over broad subscription-wide changes.
- Run production `what-if` before approval.
