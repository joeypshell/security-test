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

# Import token acquisition, Graph request, and pagination helpers into this scope.
. (Join-Path $PSScriptRoot '..\shared\GraphAccess.ps1')

# Production state is never accepted without an operator-supplied change record,
# even if this script is called directly outside the GitHub workflow.
if ($TargetState -eq 'enabled' -and [string]::IsNullOrWhiteSpace($ChangeTicket)) {
    throw 'Production enablement requires a change ticket.'
}

# Repository vocabulary stays readable while the outgoing payload uses the exact
# state values required by the Microsoft Graph Conditional Access schema.
$graphState = switch ($TargetState) {
    'reportOnly' { 'enabledForReportingButNotEnforced' }
    'enabled' { 'enabled' }
}

$normalizedGraphBaseUri = $GraphBaseUri.TrimEnd('/')
$resolvedPolicyPath = Resolve-Path -LiteralPath $PolicyPath

# Only top-level JSON files in the policy directory are deployment definitions.
$policyFiles = Get-ChildItem -LiteralPath $resolvedPolicyPath -Filter '*.json' -File

if ($policyFiles.Count -eq 0) {
    throw "No Conditional Access policy files found under $resolvedPolicyPath."
}

$policyDefinitions = @()
$seenDisplayNames = @{}

foreach ($file in $policyFiles) {
    # Parse into an object so state enforcement and removal of Graph-managed
    # properties are structural operations rather than string replacements.
    $policy = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($policy.displayName)) {
        throw "$($file.Name): displayName is required."
    }

    # displayName is the repository's stable upsert key. Reject duplicates before
    # contacting Graph because they would make repository intent ambiguous.
    $displayNameKey = $policy.displayName.ToLowerInvariant()
    if ($seenDisplayNames.ContainsKey($displayNameKey)) {
        throw "$($file.Name): duplicate displayName '$($policy.displayName)' also appears in $($seenDisplayNames[$displayNameKey])."
    }

    $seenDisplayNames[$displayNameKey] = $file.Name

    # The protected target environment overrides any state stored in the file.
    $stateProperty = $policy.PSObject.Properties['state']
    if ($stateProperty) {
        $stateProperty.Value = $graphState
    }
    else {
        $policy | Add-Member -NotePropertyName state -NotePropertyValue $graphState
    }

    # Exported Graph objects contain server-managed values that cannot be sent in
    # create or update payloads. Remove them when present.
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

# Plan mode deliberately returns before token acquisition. It validates and shows
# intent without requiring tenant access or making a Graph request.
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

# Apply mode starts by obtaining a Graph token for the federated managed identity
# and loading all existing policies needed for exact display-name matching.
$accessToken = Get-GraphAccessToken -ProvidedAccessToken $GraphAccessToken
$existingPoliciesUri = "$normalizedGraphBaseUri/identity/conditionalAccess/policies?`$select=id,displayName,state"
$existingPolicies = @(Get-GraphCollection -Uri $existingPoliciesUri -AccessToken $accessToken)

foreach ($definition in $policyDefinitions) {
    $policy = $definition.Policy
    $body = $policy | ConvertTo-Json -Depth 50
    $matchingPolicies = @($existingPolicies | Where-Object { $_.displayName -eq $policy.displayName })

    # More than one tenant policy with the same display name is unsafe to resolve
    # automatically. Stop instead of updating an arbitrary policy.
    if ($matchingPolicies.Count -gt 1) {
        throw "Multiple existing Conditional Access policies have displayName '$($policy.displayName)'. Refusing to choose one."
    }

    # One exact match is updated in place; no match creates a new policy. The
    # SupportsShouldProcess checks preserve -WhatIf behavior for direct callers.
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
