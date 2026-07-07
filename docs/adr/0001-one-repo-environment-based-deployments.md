# ADR 0001: One Repo with Environment-Based Deployments

## Status

Accepted for the test repository.

## Context

This repo is intended to model security infrastructure deployment for Azure controls such as Key Vaults, NSGs, WAF policies, Azure Policy, and eventually Conditional Access.

A branch-per-environment model would make `dev`, `qa`, and `prod` branches behave like deployment targets. That creates drift risk because different branches can contain different source definitions for the same control.

The safer pattern is to keep one protected source of truth and promote the same reviewed commit through increasingly sensitive deployment targets.

## Decision

Use one repository for security infrastructure and separate concerns with folders, workflows, CODEOWNERS, and GitHub Environments.

- Use `main` as the protected source of truth.
- Use short-lived feature branches for changes.
- Use GitHub Environments as Azure target, identity, and approval boundaries.
- Use Bicep for deployments.
- Do not create long-lived environment branches.
- Split deployment lanes by workflow, not by repo, unless ownership or risk boundaries require it later.

## Consequences

### Benefits

- One PR can safely coordinate related Key Vault, network, WAF, and policy changes.
- The same commit can be promoted through lower and production environments.
- Environment-specific Azure identities and approvals stay in GitHub Environment configuration.
- Path-based CODEOWNERS can assign review responsibility by control area.
- Shared modules can be reused across deployment lanes.

### Tradeoffs

- Workflows need clear path filters and deployment-class checks.
- Production environments must be configured carefully to avoid accidental ungated deployment.
- Some tenant-wide controls, especially Conditional Access, may eventually justify a stricter repo or approval boundary.

## Current implementation

Key Vaults are the first implemented lane.

- `kv-dev` is the lower app lifecycle target.
- `keys-prod` is the production app lifecycle target.
- `keys-shared` is the shared or keys-only target.
- `.github/workflows/deploy-keyvault.yml` handles the Key Vault lane.
- `.github/workflows/validate.yml` handles shared validation.

## Review trigger for future split

Revisit the one-repo decision if any of these become true:

- Different teams need independent write access boundaries.
- A control area needs substantially stricter confidentiality.
- Deployment cadence between control areas creates review friction.
- The repo grows large enough that agent or human review quality drops.
- Tenant-wide identity controls need a separate governance process.
