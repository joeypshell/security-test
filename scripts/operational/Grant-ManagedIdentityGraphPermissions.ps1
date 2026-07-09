<#
.SYNOPSIS
Grants the Conditional Access Microsoft Graph application permissions to managed identities.

.DESCRIPTION
Uses an interactive Microsoft Entra PowerShell session to assign the minimum Graph app roles
required by the Conditional Access deployment workflow. Run this only during identity setup.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [guid] $TenantId,

    [Parameter(Mandatory)]
    [guid[]] $ManagedIdentityClientId,

    [ValidateSet('Policy.Read.All', 'Policy.ReadWrite.ConditionalAccess')]
    [string[]] $Permission = @(
        'Policy.Read.All',
        'Policy.ReadWrite.ConditionalAccess'
    )
)

$ErrorActionPreference = 'Stop'

$requiredCommands = @(
    'Connect-Entra',
    'Get-EntraServicePrincipal',
    'Get-EntraServicePrincipalAppRoleAssignment',
    'New-EntraServicePrincipalAppRoleAssignment'
)

foreach ($commandName in $requiredCommands) {
    if (!(Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "Microsoft Entra PowerShell command '$commandName' is unavailable. Install the Microsoft.Entra module first."
    }
}

Connect-Entra `
    -TenantId $TenantId `
    -Scopes 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All' | Out-Null

$graphServicePrincipals = @(
    Get-EntraServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
)

if ($graphServicePrincipals.Count -ne 1) {
    throw "Expected one Microsoft Graph service principal, found $($graphServicePrincipals.Count)."
}

$graphServicePrincipal = $graphServicePrincipals[0]

foreach ($clientId in $ManagedIdentityClientId) {
    $managedIdentityServicePrincipals = @(
        Get-EntraServicePrincipal -Filter "appId eq '$($clientId.Guid)' and servicePrincipalType eq 'ManagedIdentity'"
    )

    if ($managedIdentityServicePrincipals.Count -ne 1) {
        throw "Expected one managed identity service principal for client ID $clientId, found $($managedIdentityServicePrincipals.Count)."
    }

    $managedIdentityServicePrincipal = $managedIdentityServicePrincipals[0]
    $currentAssignments = @(
        Get-EntraServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityServicePrincipal.Id
    )

    foreach ($permissionName in $Permission) {
        $appRoles = @(
            $graphServicePrincipal.AppRoles | Where-Object {
                $_.Value -eq $permissionName -and $_.AllowedMemberTypes -contains 'Application'
            }
        )

        if ($appRoles.Count -ne 1) {
            throw "Expected one Microsoft Graph application role named '$permissionName', found $($appRoles.Count)."
        }

        $appRole = $appRoles[0]
        $existingAssignment = $currentAssignments | Where-Object {
            $_.ResourceId -eq $graphServicePrincipal.Id -and $_.AppRoleId -eq $appRole.Id
        }

        if ($existingAssignment) {
            Write-Output "$($managedIdentityServicePrincipal.DisplayName) already has $permissionName."
            continue
        }

        $target = "$($managedIdentityServicePrincipal.DisplayName) ($clientId)"
        if ($PSCmdlet.ShouldProcess($target, "Grant Microsoft Graph application permission $permissionName")) {
            $assignmentParameters = @{
                ServicePrincipalId = $managedIdentityServicePrincipal.Id
                PrincipalId = $managedIdentityServicePrincipal.Id
                ResourceId = $graphServicePrincipal.Id
                AppRoleId = $appRole.Id
            }

            New-EntraServicePrincipalAppRoleAssignment @assignmentParameters | Out-Null
            Write-Output "Granted $permissionName to $($managedIdentityServicePrincipal.DisplayName)."
        }
    }
}
