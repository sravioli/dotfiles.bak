<#
.SYNOPSIS
    Template script for task execution.

.DESCRIPTION
    This is a template Run.ps1 script that executes when the scheduled task triggers.
    Customize this script for your specific needs.

.NOTES
    Author: Your Name
    Version: 1.0.0
    Created: $(Get-Date -Format 'yyyy-MM-dd')
#>

[CmdletBinding()]
param()

#region Configuration

# Set error action preference
$ErrorActionPreference = 'Stop'

# Get script directory
$ScriptRoot = $PSScriptRoot

#endregion

#region Load Environment Variables

# Load .env file if it exists
$EnvFile = Join-Path $ScriptRoot '.env'
if (Test-Path $EnvFile) {
    Write-Verbose 'Loading environment variables from .env'
    
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            return
        }
        
        # Parse key=value
        if ($line -match '^\s*([^#=]+?)\s*=\s*(.+?)\s*$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # Remove quotes if present
            $value = $value -replace '^["'']|["'']$', ''
            
            Set-Variable -Name $key -Value $value -Scope Script
            Write-Verbose "  $key = $value"
        }
    }
}
else {
    Write-Verbose "No .env file found at $EnvFile"
}

#endregion

#region Main Logic

try {
    Write-Verbose "Starting task execution at $(Get-Date)"
    
    # ========================================
    # YOUR TASK LOGIC GOES HERE
    # ========================================
    
    # Example: Log execution
    $LogMessage = "Task executed successfully at $(Get-Date)"
    Write-Host $LogMessage -ForegroundColor Green
    
    # Example: Check if we have required environment variables
    if ($env:COMPUTERNAME) {
        Write-Verbose "Running on computer: $env:COMPUTERNAME"
    }
    
    # Example: Do some work
    # ...
    
    # ========================================
    # END OF TASK LOGIC
    # ========================================
    
    Write-Verbose "Task completed successfully at $(Get-Date)"
    exit 0
}
catch {
    Write-Error "Task failed: $_"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Cleanup if needed
    Write-Verbose 'Cleaning up...'
}

#endregion
