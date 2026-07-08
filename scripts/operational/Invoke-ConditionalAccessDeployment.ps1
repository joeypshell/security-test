<#
.SYNOPSIS
Plans or applies Conditional Access policy state changes.

.DESCRIPTION
Reads Conditional Access JSON policy definitions, forces the requested target state, and upserts each policy by display name through Microsoft Graph.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $PolicyPath,

    [Parameter(Mandatory)]
    [ValidateSet('reportOnly', 'enabled')]
    [string] $TargetState,

    [string] $ChangeTicket,

    [switch] $Apply,

    [string] $GraphBaseUri = 'https://graph.microsoft.com/v1.0',

    [securestring] $GraphAccessToken
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\shared\GraphAccess.ps1')

if ($TargetState -eq 'enabled' -and [string]::IsNullOrWhiteSpace($ChangeTicket)) {
    throw 'Production enablement requires a change ticket.'
}

$normalizedGraphBaseUri = $GraphBaseUri.TrimEnd('/')
$resolvedPolicyPath = Resolve-Path -LiteralPath $PolicyPath
$policyFiles = Get-ChildItem -LiteralPath $resolvedPolicyPath -Filter '*.json' -File

if ($policyFiles.Count -eq 0) {
    throw "No Conditional Access policy files found under $resolvedPolicyPath."
}

$policyDefinitions = @()
$seenDisplayNames = @{}

foreach ($file in $policyFiles) {
    $policy = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($policy.displayName)) {
        throw "$($file.Name): displayName is required."
    }

    $displayNameKey = $policy.displayName.ToLowerInvariant()
    if ($seenDisplayNames.ContainsKey($displayNameKey)) {
        throw "$($file.Name): duplicate displayName '$($policy.displayName)' also appears in $($seenDisplayNames[$displayNameKey])."
    }

    $seenDisplayNames[$displayNameKey] = $file.Name

    $stateProperty = $policy.PSObject.Properties['state']
    if ($stateProperty) {
        $stateProperty.Value = $TargetState
    }
    else {
        $policy | Add-Member -NotePropertyName state -NotePropertyValue $TargetState
    }

    foreach ($readOnlyPropertyName in '@odata.context', 'id', 'createdDateTime', 'modifiedDateTime') {
        if ($policy.PSObject.Properties[$readOnlyPropertyName]) {
            $policy.PSObject.Properties.Remove($readOnlyPropertyName)
        }
    }

    $policyDefinitions += [pscustomobject]@{
        File = $file
        Policy = $policy
    }
}

if (!$Apply) {
    foreach ($definition in $policyDefinitions) {
        $message = "Upsert '$($definition.Policy.displayName)' to '$TargetState'"
        if ($ChangeTicket) {
            $message = "$message under change ticket '$ChangeTicket'"
        }

        Write-Output "PLAN: $message"
    }

    return
}

$accessToken = Get-GraphAccessToken -ProvidedAccessToken $GraphAccessToken
$existingPoliciesUri = "$normalizedGraphBaseUri/identity/conditionalAccess/policies?`$select=id,displayName,state"
$existingPolicies = @(Get-GraphCollection -Uri $existingPoliciesUri -AccessToken $accessToken)

foreach ($definition in $policyDefinitions) {
    $policy = $definition.Policy
    $body = $policy | ConvertTo-Json -Depth 50
    $matchingPolicies = @($existingPolicies | Where-Object { $_.displayName -eq $policy.displayName })

    if ($matchingPolicies.Count -gt 1) {
        throw "Multiple existing Conditional Access policies have displayName '$($policy.displayName)'. Refusing to choose one."
    }

    if ($matchingPolicies.Count -eq 1) {
        $existingPolicy = $matchingPolicies[0]
        $policyUri = "$normalizedGraphBaseUri/identity/conditionalAccess/policies/$($existingPolicy.id)"
        if ($PSCmdlet.ShouldProcess($policy.displayName, "Update Conditional Access policy state to $TargetState")) {
            Invoke-GraphRequest -Method PATCH -Uri $policyUri -AccessToken $accessToken -Body $body | Out-Null
            Write-Output "UPDATED: $($policy.displayName) ($($existingPolicy.id))"
        }
    }
    else {
        $policyUri = "$normalizedGraphBaseUri/identity/conditionalAccess/policies"
        if ($PSCmdlet.ShouldProcess($policy.displayName, "Create Conditional Access policy with state $TargetState")) {
            $createdPolicy = Invoke-GraphRequest -Method POST -Uri $policyUri -AccessToken $accessToken -Body $body
            Write-Output "CREATED: $($policy.displayName) ($($createdPolicy.id))"
        }
    }
}
