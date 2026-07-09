<#
.SYNOPSIS
Exports current tenant state before identity changes.

.DESCRIPTION
Exports Conditional Access policies from Microsoft Graph so reviewers have a pre-change snapshot.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $OutputPath = 'tenant-state-export.json',

    [string] $GraphBaseUri = 'https://graph.microsoft.com/v1.0',

    [securestring] $GraphAccessToken
)

$ErrorActionPreference = 'Stop'

# Reuse the same token acquisition and paginated Graph helpers as deployment.
. (Join-Path $PSScriptRoot '..\shared\GraphAccess.ps1')

# WhatIf must not require tenant credentials. Record the intended operation and
# return before token acquisition or network access.
if ($WhatIfPreference) {
    [void] $PSCmdlet.ShouldProcess($OutputPath, 'Export Conditional Access policies from Microsoft Graph')
    return
}

$normalizedGraphBaseUri = $GraphBaseUri.TrimEnd('/')
$accessToken = Get-GraphAccessToken -ProvidedAccessToken $GraphAccessToken

# Export the complete collection before apply so reviewers retain a pre-change
# tenant snapshot as a GitHub Actions artifact.
$policies = Get-GraphCollection -Uri "$normalizedGraphBaseUri/identity/conditionalAccess/policies" -AccessToken $accessToken

# Include provenance and a UTC timestamp alongside the raw Graph policy objects.
$export = [ordered]@{
    exportedAt = (Get-Date).ToUniversalTime().ToString('o')
    source = 'microsoft-graph'
    conditionalAccessPolicies = @($policies)
}

# SupportsShouldProcess protects the local file write for direct administrative use.
if ($PSCmdlet.ShouldProcess($OutputPath, 'Write tenant state export')) {
    $export | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    Write-Output "Wrote $OutputPath"
}
