# Local Validation

Run local checks before opening a PR:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validation/Invoke-LocalValidation.ps1
```

Optional tools:

- Azure CLI with Bicep support
- PSScriptAnalyzer

CI remains the source of truth. Local validation is a fast pre-check.
