<#
.SYNOPSIS
Validates Conditional Access policy JSON files before deployment.

.DESCRIPTION
Checks JSON syntax, default reportOnly state, and required break-glass exclusions.
#>
[CmdletBinding()]
param(
    [string] $PolicyPath = (Join-Path $PSScriptRoot '..\policies'),
    [string] $RequiredBreakGlassPath = (Join-Path $PSScriptRoot '..\required-break-glass-ids.json'),
    [switch] $AllowEnabledPolicy
)

$ErrorActionPreference = 'Stop'

# Collect every policy defect so a pull request receives one complete validation
# report instead of requiring one workflow run per failure.
$failures = [System.Collections.Generic.List[string]]::new()

# Both the policy directory and the central emergency-access list are mandatory
# inputs. Missing either is a repository configuration error, not a policy error.
if (!(Test-Path -LiteralPath $PolicyPath)) {
    throw "Policy path not found: $PolicyPath"
}

if (!(Test-Path -LiteralPath $RequiredBreakGlassPath)) {
    throw "Required break-glass file not found: $RequiredBreakGlassPath"
}

# The central list is authoritative: every policy must exclude every listed ID.
$required = Get-Content -LiteralPath $RequiredBreakGlassPath -Raw | ConvertFrom-Json
$requiredExcludeUsers = @($required.excludeUsers)

if ($requiredExcludeUsers.Count -eq 0) {
    $failures.Add('At least one required break-glass exclusion ID must be configured.')
}

$policyFiles = Get-ChildItem -LiteralPath $PolicyPath -Filter '*.json' -File
if ($policyFiles.Count -eq 0) {
    $failures.Add("No Conditional Access policy JSON files found under $PolicyPath.")
}

foreach ($file in $policyFiles) {
    # Parse each file independently so invalid JSON in one file does not hide
    # validation results from the remaining policy files.
    try {
        $policy = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    }
    catch {
        $failures.Add("$($file.Name): invalid JSON. $($_.Exception.Message)")
        continue
    }

    # displayName is required because deployment uses it as the exact upsert key.
    if ([string]::IsNullOrWhiteSpace($policy.displayName)) {
        $failures.Add("$($file.Name): displayName is required.")
    }

    # Source-controlled policies default to reportOnly. Production state is
    # selected by the protected entra-prod GitHub Environment at runtime.
    if (!$AllowEnabledPolicy -and $policy.state -ne 'reportOnly') {
        $failures.Add("$($file.Name): state must default to reportOnly.")
    }

    # Enforce the same emergency-access exclusions in every policy definition.
    $excludedUsers = @($policy.conditions.users.excludeUsers)
    foreach ($requiredUser in $requiredExcludeUsers) {
        if ($excludedUsers -notcontains $requiredUser) {
            $failures.Add("$($file.Name): missing break-glass exclusion $requiredUser.")
        }
    }

    # A policy that targets all users must have at least one explicit exclusion,
    # even when the central required list is temporarily misconfigured.
    $targetsAllUsers = @($policy.conditions.users.includeUsers) -contains 'All'
    if ($targetsAllUsers -and $excludedUsers.Count -eq 0) {
        $failures.Add("$($file.Name): policies targeting all users must define exclusions.")
    }
}

# Emit each specific failure before the terminating summary used by CI.
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Conditional Access policy validation failed with $($failures.Count) issue(s)."
}

Write-Host "Conditional Access policy validation passed."
