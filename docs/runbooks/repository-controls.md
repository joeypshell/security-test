# Repository Controls

Recommended repository controls:

- protect `main`
- require pull requests before merge
- require CODEOWNERS review for sensitive paths
- require `PR Validate` checks
- enable secret scanning and push protection
- enable Dependabot alerts and updates
- keep deployment workflows restricted to `main`

Sensitive paths:

- `.github/workflows/`
- `infra/`
- `identity/`
- `scripts/`

The custom policy gate in `scripts/validation/Test-RepoPolicy.ps1` is intentionally simple. Extend it with organization-specific rules as real controls are identified.
