<#
.SYNOPSIS
    Structured logging functions for PowerShell tasks.

.DESCRIPTION
    Provides timestamped, color-coded logging with multiple severity levels.

.NOTES
    Author: Task Management System
    Version: 2.0.0
    Last Updated: 2025-11-11
#>

function Write-TaskLog {
    <#
    .SYNOPSIS
        Writes timestamped, color-coded log messages.
    
    .DESCRIPTION
        Provides structured logging with timestamp, severity level, and color coding.
        Compatible with both interactive and non-interactive sessions.
    
    .PARAMETER Message
        The message to log.
    
    .PARAMETER Level
        The severity level: Info, Success, Warning, Error, Verbose, Debug.
    
    .PARAMETER NoTimestamp
        Omit the timestamp from the log message.
    
    .EXAMPLE
        Write-TaskLog "Task started" -Level Info
    
    .EXAMPLE
        Write-TaskLog "Operation completed successfully" -Level Success
    
    .EXAMPLE
        Write-TaskLog "Configuration error" -Level Error
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,
        
        [Parameter(Position = 1)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Verbose', 'Debug')]
        [string]$Level = 'Info',
        
        [Parameter()]
        [switch]$NoTimestamp
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = if ($NoTimestamp) { 
        "[$Level] $Message" 
    } 
    else { 
        "[$timestamp] [$Level] $Message" 
    }
    
    switch ($Level) {
        'Success' { 
            Write-Host $logMessage -ForegroundColor Green 
        }
        'Warning' { 
            Write-Warning $logMessage 
        }
        'Error' { 
            Write-Error $logMessage 
        }
        'Verbose' { 
            Write-Verbose $logMessage 
        }
        'Debug' { 
            Write-Debug $logMessage 
        }
        default { 
            Write-Host $logMessage -ForegroundColor Cyan
        }
    }
}

function Write-TaskSeparator {
    <#
    .SYNOPSIS
        Writes a visual separator line to logs.
    
    .PARAMETER Character
        Character to use for the separator. Default is '='.
    
    .PARAMETER Length
        Length of the separator line. Default is 60.
    
    .EXAMPLE
        Write-TaskSeparator
        # Writes: ============================================================
    
    .EXAMPLE
        Write-TaskSeparator -Character '-' -Length 40
        # Writes: ----------------------------------------
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [char]$Character = '=',
        
        [Parameter()]
        [int]$Length = 60
    )
    
    Write-TaskLog ($Character.ToString() * $Length) -Level Info -NoTimestamp
}

Export-ModuleMember -Function @(
    'Write-TaskLog',
    'Write-TaskSeparator'
)
