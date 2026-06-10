<#
.SYNOPSIS
    Environment variable management for PowerShell tasks.

.DESCRIPTION
    Provides functionality to load and manage environment variables from .env files.

.NOTES
    Author: Task Management System
    Version: 2.0.0
    Last Updated: 2025-11-11
#>

function Import-TaskEnvironment {
    <#
    .SYNOPSIS
        Loads environment variables from a .env file.
    
    .DESCRIPTION
        Parses a .env file and returns variables as a hashtable.
        Supports comments (#), empty lines, and quoted values.
    
    .PARAMETER Path
        Path to the .env file. Defaults to .env in the script's directory.
    
    .EXAMPLE
        $envVars = Import-TaskEnvironment
        # Loads .env from the current script directory
    
    .EXAMPLE
        $envVars = Import-TaskEnvironment -Path "C:\config\.env"
        # Loads .env from a specific path
    
    .OUTPUTS
        Hashtable containing the loaded variables
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('dotenv')]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = '.env'
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "Environment file not found: $Path"
        return @{}
    }

    $envVars = @{}

    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            return
        }
        
        # Parse name=value pairs
        $separatorIndex = $line.IndexOf('=')
        if ($separatorIndex -eq -1) {
            Write-Verbose "Skipping invalid line (no '=' found): $line"
            return
        }
        
        $name = $line.Substring(0, $separatorIndex).Trim()
        $value = $line.Substring($separatorIndex + 1).Trim()
        
        # Remove surrounding quotes if present
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or 
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        
        $envVars[$name] = $value
    }

    Write-Verbose "Loaded $($envVars.Count) variables from $Path"
    if ($VerbosePreference -eq 'Continue') {
        Write-Verbose ($envVars | Format-Table -AutoSize | Out-String)
    }
    
    return $envVars
}

Export-ModuleMember -Function 'Import-TaskEnvironment' -Alias 'dotenv'
