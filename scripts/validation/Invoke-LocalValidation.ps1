<#
.SYNOPSIS
Runs local validation checks for this repository.

.DESCRIPTION
Executes custom policy checks and uses optional local tools when they are installed.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Push-Location $repoRoot
try {
    # Match the custom policy gates used by pull-request validation before
    # running optional local analyzers and Bicep compilation.
    ./scripts/validation/Test-RepoPolicy.ps1
    ./identity/conditional-access/tests/Test-ConditionalAccessPolicy.ps1

    if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
        $scriptAnalyzerResults = Invoke-ScriptAnalyzer -Path scripts -Recurse -Severity Warning,Error
        $scriptAnalyzerResults | Format-Table -AutoSize
        if ($scriptAnalyzerResults) {
            throw 'PSScriptAnalyzer found issues.'
        }
    }
    else {
        Write-Warning 'PSScriptAnalyzer is not installed. Skipping PowerShell static analysis.'
    }

    if (Get-Command az -ErrorAction SilentlyContinue) {
        $bicepFiles = Get-ChildItem -Path infra -Recurse -Filter *.bicep
        foreach ($file in $bicepFiles) {
            az bicep build --file $file.FullName
        }

        $paramFiles = Get-ChildItem -Path infra -Recurse -Filter *.bicepparam
        foreach ($file in $paramFiles) {
            az bicep build-params --file $file.FullName
        }
    }
    else {
        Write-Warning 'Azure CLI is not installed. Skipping Bicep build checks.'
    }

    Write-Output 'Local validation completed.'
}
finally {
    Pop-Location
}
