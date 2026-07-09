<#
.SYNOPSIS
Runs repository-specific security policy checks.

.DESCRIPTION
This script catches high-risk patterns that generic scanners usually miss in infrastructure repositories.
#>
[CmdletBinding()]
param(
    [string] $RootPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch] $AllowOwnerRoleAssignment,
    [switch] $AllowEnabledConditionalAccess
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string] $Message)
    $script:failures.Add($Message)
}

$textFiles = Get-ChildItem -LiteralPath $RootPath -Recurse -File -Include *.bicep,*.bicepparam,*.json,*.ps1 |
    Where-Object {
        $_.FullName -notmatch '\\.git\\' -and
        $_.FullName -ne $PSCommandPath
    }

$ownerRoleDefinitionGuid = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
$userAccessAdminRoleName = 'User Access' + ' Administrator'
$userAccessAdminRoleDefinitionGuid = 'f1a07417-d97a-45cb-824c-7a7467783830'

foreach ($file in $textFiles) {
    $relativePath = Resolve-Path -LiteralPath $file.FullName -Relative
    $content = Get-Content -LiteralPath $file.FullName -Raw

    if (!$AllowOwnerRoleAssignment -and $content -match $ownerRoleDefinitionGuid) {
        Add-Failure "$relativePath references the Owner role definition. Require explicit exception approval."
    }

    if ($content -match $userAccessAdminRoleName -or $content -match $userAccessAdminRoleDefinitionGuid) {
        Add-Failure "$relativePath references User Access Administrator. Require explicit exception approval."
    }

    if ($file.Extension -in '.bicep', '.bicepparam') {
        if ($content -match "enablePurgeProtection\s*[:=]\s*false") {
            Add-Failure "$relativePath disables Key Vault purge protection."
        }

        if ($content -match "publicNetworkAccess\s*[:=]\s*'Enabled'") {
            Add-Failure "$relativePath enables public network access."
        }
    }

    # Source-controlled Conditional Access definitions must remain report-only.
    # The protected deployment environment is the only normal state promotion path.
    if (!$AllowEnabledConditionalAccess -and $relativePath -match 'identity[\\/]conditional-access[\\/]policies' -and $content -match '"state"\s*:\s*"enabled"') {
        Add-Failure "$relativePath enables a Conditional Access policy directly. Use reportOnly first."
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Repository policy validation failed with $($failures.Count) issue(s)."
}

Write-Output "Repository policy validation passed."
