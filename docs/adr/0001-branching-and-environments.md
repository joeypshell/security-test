# ADR 0001: Branching and Environment Model

## Status

Accepted for this test repository.

## Decision

Use short-lived feature branches and one protected `main` branch. Use GitHub Environments, parameter files, and Azure identities to represent deployment targets.

For Key Vault, use these GitHub Environments:

- `kv-dev` for the Key Vault development subscription
- `kv-qa` for the Key Vault QA subscription
- `keys-prod` for production app Key Vaults in the `keys` subscription
- `keys-shared` for shared, departmental, or keys-only vaults in the `keys` subscription

## Rationale

Infrastructure code should promote the same reviewed commit through increasingly sensitive targets. Long-lived `dev`, `qa`, `prod`, or `keys` branches make it easy for each environment to drift into a different version of reality.

## Consequences

- PRs validate code before merge.
- `main` is the source of deployable truth.
- Environment approvals gate deployments.
- Parameter files hold target-specific configuration.
- Azure OIDC identities are scoped per target.
- The `keys` subscription is split into `keys-prod` and `keys-shared` approval paths without creating separate branches.
- `keys-prod`, `keys-shared`, and `entra-prod` can have stricter approvals without creating separate branches.
