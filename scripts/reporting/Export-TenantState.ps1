<#
.SYNOPSIS
Exports current tenant state before identity changes.

.DESCRIPTION
Creates a placeholder export artifact in this test repo. Replace the data collection block with Microsoft Graph export calls when connected to a real tenant.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $OutputPath = 'tenant-state-export.json'
)

$ErrorActionPreference = 'Stop'

$export = [ordered]@{
    exportedAt = (Get-Date).ToUniversalTime().ToString('o')
    source = 'placeholder'
    note = 'Replace this with Microsoft Graph export data before production use.'
    conditionalAccessPolicies = @()
}

if ($PSCmdlet.ShouldProcess($OutputPath, 'Write tenant state export')) {
    $export | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    Write-Output "Wrote $OutputPath"
}
