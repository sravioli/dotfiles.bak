# General Utilities
# Miscellaneous utility functions

function Invoke-JsonPreview { 
    <#
    .SYNOPSIS
        Pretty prints JSON files with syntax highlighting
    .DESCRIPTION
        Uses jq and bat to display JSON files with proper formatting and colors
    .PARAMETER Path
        Path to the JSON file(s) to preview
    .EXAMPLE
        Invoke-JsonPreview config.json
        Displays the config.json file with syntax highlighting
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$Path
    )
    
    process {
        foreach ($file in $Path) {
            if (-not (Test-Path $file)) {
                Write-Warning "File not found: $file"
                continue
            }
            
            try {
                Get-Content -Path $file | jq . --color-output | bat --style=plain --language=json
            }
            catch {
                Write-Warning "Failed to process JSON file '$file': $_"
                # Fallback to simple display
                Get-Content -Path $file
            }
        }
    }
}
Set-Alias -Name json -Value Invoke-JsonPreview

function Test-ExecutableExists {
    <#
    .SYNOPSIS
        Checks if a given executable is available in the system PATH.
    .DESCRIPTION
        Uses Get-Command to determine if the specified executable exists.
    .PARAMETER Name
        The name of the executable (e.g., 'fd', 'git', 'dotnet').
    .EXAMPLE
        Test-ExecutableExists -Name fd
        Returns $true if fd is installed, otherwise $false.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    return [bool]$cmd
}