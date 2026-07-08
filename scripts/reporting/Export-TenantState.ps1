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

. (Join-Path $PSScriptRoot '..\shared\GraphAccess.ps1')

if ($WhatIfPreference) {
    [void] $PSCmdlet.ShouldProcess($OutputPath, 'Export Conditional Access policies from Microsoft Graph')
    return
}

$normalizedGraphBaseUri = $GraphBaseUri.TrimEnd('/')
$accessToken = Get-GraphAccessToken -ProvidedAccessToken $GraphAccessToken
$policies = Get-GraphCollection -Uri "$normalizedGraphBaseUri/identity/conditionalAccess/policies" -AccessToken $accessToken

$export = [ordered]@{
    exportedAt = (Get-Date).ToUniversalTime().ToString('o')
    source = 'microsoft-graph'
    conditionalAccessPolicies = @($policies)
}

if ($PSCmdlet.ShouldProcess($OutputPath, 'Write tenant state export')) {
    $export | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    Write-Output "Wrote $OutputPath"
}
