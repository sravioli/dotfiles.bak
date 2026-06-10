function Read-CompletionManifest {
    <#
    .SYNOPSIS
        Reads and parses a completion manifest.json file.
    .DESCRIPTION
        Returns the parsed manifest object, or $null if the file does not exist or is invalid JSON.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        Get-Content -Path $Path -Raw | ConvertFrom-Json
    }
    catch {
        Write-Warning "Failed to read manifest: $Path - $_"
        return $null
    }
}
