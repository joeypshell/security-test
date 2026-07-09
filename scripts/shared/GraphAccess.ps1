function ConvertTo-PlainText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [securestring] $SecureValue
    )

    # Marshal only long enough to supply the bearer token to the HTTP client,
    # then zero the unmanaged buffer even when conversion throws.
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Get-GraphAccessToken {
    [CmdletBinding()]
    param(
        [securestring] $ProvidedAccessToken
    )

    # Explicit input is highest priority so tests and controlled local runs can
    # avoid depending on ambient Azure CLI or Az PowerShell state.
    if ($ProvidedAccessToken) {
        return ConvertTo-PlainText -SecureValue $ProvidedAccessToken
    }

    # Environment token support is useful for non-interactive tooling, but the
    # GitHub workflow normally uses the Azure CLI path below.
    if (![string]::IsNullOrWhiteSpace($env:GRAPH_ACCESS_TOKEN)) {
        return $env:GRAPH_ACCESS_TOKEN
    }

    # azure/login configures this CLI session through GitHub OIDC. Requesting the
    # Graph resource converts that session into a short-lived Graph bearer token.
    $azCommand = Get-Command az -ErrorAction SilentlyContinue
    if ($azCommand) {
        $token = & $azCommand.Source account get-access-token `
            --resource https://graph.microsoft.com `
            --query accessToken `
            --output tsv 2>$null

        if ($LASTEXITCODE -eq 0 -and ![string]::IsNullOrWhiteSpace($token)) {
            return ($token | Out-String).Trim()
        }
    }

    # Az PowerShell is a local-administration fallback when Azure CLI is absent.
    $getAzAccessTokenCommand = Get-Command Get-AzAccessToken -ErrorAction SilentlyContinue
    if ($getAzAccessTokenCommand) {
        try {
            $tokenResult = Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com' -ErrorAction Stop
            if ($tokenResult.Token -is [securestring]) {
                return ConvertTo-PlainText -SecureValue $tokenResult.Token
            }

            if (![string]::IsNullOrWhiteSpace($tokenResult.Token)) {
                return $tokenResult.Token
            }
        }
        catch {
            Write-Verbose "Get-AzAccessToken failed: $($_.Exception.Message)"
        }
    }

    throw 'Microsoft Graph access token was not available. Run azure/login first, connect with Az PowerShell, or set GRAPH_ACCESS_TOKEN.'
}

function Invoke-GraphRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PATCH')]
        [string] $Method,

        [Parameter(Mandatory)]
        [string] $Uri,

        [Parameter(Mandatory)]
        [string] $AccessToken,

        [string] $Body
    )

    # Every Graph request uses the same bearer-token and terminating-error policy.
    # Invoke-RestMethod then returns deserialized JSON to the calling script.
    $parameters = @{
        Method = $Method
        Uri = $Uri
        Headers = @{
            Authorization = "Bearer $AccessToken"
        }
        ErrorAction = 'Stop'
    }

    # GET requests omit the body; POST and PATCH payloads are JSON policy objects.
    if (![string]::IsNullOrWhiteSpace($Body)) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = $Body
    }

    Invoke-RestMethod @parameters
}

function Get-GraphCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Uri,

        [Parameter(Mandatory)]
        [string] $AccessToken
    )

    # Graph collections may span multiple pages. Follow @odata.nextLink until the
    # service stops returning one so callers always receive the complete set.
    $items = @()
    $nextUri = $Uri

    while ($nextUri) {
        $response = Invoke-GraphRequest -Method GET -Uri $nextUri -AccessToken $AccessToken
        if ($null -ne $response.value) {
            $items += @($response.value)
        }

        $nextUri = $response.'@odata.nextLink'
    }

    $items
}
