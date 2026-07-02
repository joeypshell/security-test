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
$failures = [System.Collections.Generic.List[string]]::new()

if (!(Test-Path -LiteralPath $PolicyPath)) {
    throw "Policy path not found: $PolicyPath"
}

if (!(Test-Path -LiteralPath $RequiredBreakGlassPath)) {
    throw "Required break-glass file not found: $RequiredBreakGlassPath"
}

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
    try {
        $policy = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    }
    catch {
        $failures.Add("$($file.Name): invalid JSON. $($_.Exception.Message)")
        continue
    }

    if ([string]::IsNullOrWhiteSpace($policy.displayName)) {
        $failures.Add("$($file.Name): displayName is required.")
    }

    if (!$AllowEnabledPolicy -and $policy.state -ne 'reportOnly') {
        $failures.Add("$($file.Name): state must default to reportOnly.")
    }

    $excludedUsers = @($policy.conditions.users.excludeUsers)
    foreach ($requiredUser in $requiredExcludeUsers) {
        if ($excludedUsers -notcontains $requiredUser) {
            $failures.Add("$($file.Name): missing break-glass exclusion $requiredUser.")
        }
    }

    $targetsAllUsers = @($policy.conditions.users.includeUsers) -contains 'All'
    if ($targetsAllUsers -and $excludedUsers.Count -eq 0) {
        $failures.Add("$($file.Name): policies targeting all users must define exclusions.")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Conditional Access policy validation failed with $($failures.Count) issue(s)."
}

Write-Host "Conditional Access policy validation passed."
