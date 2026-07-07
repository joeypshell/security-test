# WAF Stack

Placeholder for WAF policy deployment stacks.

## Intended model

- Lower target: `waf-dev`
- Production target: `waf-prod`
- Deployment method: Bicep
- Workflow: planned `.github/workflows/deploy-waf.yml`

## Guardrails to add before deployment

- Validate managed rule changes before production deployment.
- Separate detection/testing behavior from production enforcement.
- Require approval before production rule exclusions or broad bypasses.
- Run production `what-if` before approval.
