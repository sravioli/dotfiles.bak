function Write-CompletionManifest {
    <#
    .SYNOPSIS
        Writes a manifest.json file atomically.
    .DESCRIPTION
        Serializes the given hashtable to JSON and writes it to disk via
        a temporary file + rename to avoid partial reads.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }

    $tempPath = "$Path.tmp"
    try {
        $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $tempPath -Encoding UTF8
        Move-Item -Path $tempPath -Destination $Path -Force
    }
    catch {
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}
