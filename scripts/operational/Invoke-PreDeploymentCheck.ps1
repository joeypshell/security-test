<#
.SYNOPSIS
Runs pre-deployment checks for a stack and target.

.DESCRIPTION
Confirms that expected template and parameter files exist before a workflow attempts what-if or deploy.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('keyvault', 'sentinel')]
    [string] $Stack,

    [Parameter(Mandatory)]
    [string] $Target
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$templateFile = Join-Path $repoRoot "infra\stacks\$Stack\main.bicep"
$parameterFile = Join-Path $repoRoot "infra\stacks\$Stack\params\$Target.bicepparam"

if (!(Test-Path -LiteralPath $templateFile)) {
    throw "Template file not found: $templateFile"
}

if (!(Test-Path -LiteralPath $parameterFile)) {
    throw "Parameter file not found: $parameterFile"
}

if ($PSCmdlet.ShouldProcess("$Stack/$Target", 'Validate deployment inputs')) {
    Write-Output "Template: $templateFile"
    Write-Output "Parameters: $parameterFile"
}
