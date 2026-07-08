function ConvertTo-PlainText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [securestring] $SecureValue
    )

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

    if ($ProvidedAccessToken) {
        return ConvertTo-PlainText -SecureValue $ProvidedAccessToken
    }

    if (![string]::IsNullOrWhiteSpace($env:GRAPH_ACCESS_TOKEN)) {
        return $env:GRAPH_ACCESS_TOKEN
    }

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

    $parameters = @{
        Method = $Method
        Uri = $Uri
        Headers = @{
            Authorization = "Bearer $AccessToken"
        }
        ErrorAction = 'Stop'
    }

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
