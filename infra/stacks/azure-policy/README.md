# Azure Policy Stack

Placeholder for Azure Policy definition, initiative, assignment, and exemption deployment stacks.

## Intended model

- Lower target: `policy-dev`
- Production target: `policy-prod`
- Deployment method: Bicep
- Workflow: planned `.github/workflows/deploy-azure-policy.yml`

## Guardrails to add before deployment

- Validate deny effects separately from audit effects.
- Require a stronger review path for production deny assignments.
- Keep exemptions explicit, owned, and time-bound where possible.
- Run production `what-if` before approval.
