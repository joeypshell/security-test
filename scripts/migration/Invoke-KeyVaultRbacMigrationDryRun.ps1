<#
.SYNOPSIS
Creates a dry-run plan for Key Vault access policy to RBAC migration.

.DESCRIPTION
Accepts exported access policy data and writes a reviewable migration plan without changing Azure resources.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $InputPath,

    [string] $OutputPath = 'keyvault-migration-plan.json'
)

$ErrorActionPreference = 'Stop'

if (!(Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

$inputData = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
$plan = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    source = (Resolve-Path -LiteralPath $InputPath).Path
    proposedAssignments = @($inputData.accessPolicies)
    notes = @(
        'Review principal IDs and role mapping before applying.',
        'Highly privileged role assignments require exception approval.'
    )
}

if ($PSCmdlet.ShouldProcess($OutputPath, 'Write Key Vault RBAC migration dry-run plan')) {
    $plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    Write-Output "Wrote $OutputPath"
}
