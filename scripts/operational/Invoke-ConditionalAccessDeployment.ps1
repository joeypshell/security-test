<#
.SYNOPSIS
Plans or applies Conditional Access policy state changes.

.DESCRIPTION
This test-repo implementation performs file-based validation and emits the intended deployment plan. Replace the marked section with Microsoft Graph calls once tenant authentication is finalized.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $PolicyPath,

    [Parameter(Mandatory)]
    [ValidateSet('reportOnly', 'enabled')]
    [string] $TargetState,

    [string] $ChangeTicket,

    [switch] $Apply
)

$ErrorActionPreference = 'Stop'

if ($TargetState -eq 'enabled' -and [string]::IsNullOrWhiteSpace($ChangeTicket)) {
    throw 'Production enablement requires a change ticket.'
}

$resolvedPolicyPath = Resolve-Path -LiteralPath $PolicyPath
$policyFiles = Get-ChildItem -LiteralPath $resolvedPolicyPath -Filter '*.json' -File

if ($policyFiles.Count -eq 0) {
    throw "No Conditional Access policy files found under $resolvedPolicyPath."
}

foreach ($file in $policyFiles) {
    $policy = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    $message = "Set '$($policy.displayName)' to '$TargetState'"
    if ($ChangeTicket) {
        $message = "$message under change ticket '$ChangeTicket'"
    }

    if ($Apply) {
        if ($PSCmdlet.ShouldProcess($policy.displayName, "Apply Conditional Access state $TargetState")) {
            Write-Output $message
            Write-Warning 'Graph apply is intentionally stubbed in this test repo. Add Microsoft Graph update calls after tenant auth design is approved.'
        }
    }
    else {
        Write-Output "PLAN: $message"
    }
}
