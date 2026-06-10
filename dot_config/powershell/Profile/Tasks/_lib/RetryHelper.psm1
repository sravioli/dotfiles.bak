<#
.SYNOPSIS
    Generic retry logic helper for PowerShell tasks.

.DESCRIPTION
    Provides reusable retry mechanisms for operations that may fail temporarily.

.NOTES
    Author: Task Management System
    Version: 2.0.0
    Last Updated: 2025-11-11
#>

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic.
    
    .PARAMETER ScriptBlock
        The script block to execute.
    
    .PARAMETER MaxRetries
        Maximum number of retry attempts. Default is 3.
    
    .PARAMETER RetryDelay
        Delay in seconds between retries. Default is 2.
    
    .PARAMETER ErrorMessage
        Custom error message for logging.
    
    .PARAMETER OnRetry
        Optional script block to execute between retries (e.g., cleanup).
    
    .EXAMPLE
        Invoke-WithRetry -ScriptBlock { 
            Invoke-RestMethod -Uri "https://api.example.com" 
        }
    
    .EXAMPLE
        Invoke-WithRetry -ScriptBlock { 
            Test-Connection -ComputerName "server" -Count 1 -ErrorAction Stop
        } -MaxRetries 5 -RetryDelay 3
    
    .OUTPUTS
        Result of the script block execution or $null on failure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [int]$MaxRetries = 3,
        
        [Parameter()]
        [int]$RetryDelay = 2,
        
        [Parameter()]
        [string]$ErrorMessage = 'Operation failed',
        
        [Parameter()]
        [scriptblock]$OnRetry
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Verbose "Attempt $i of $MaxRetries"
            $result = & $ScriptBlock
            Write-Verbose "Operation succeeded on attempt $i"
            return $result
        }
        catch {
            $errorDetails = $_.Exception.Message
            Write-Verbose "$ErrorMessage (attempt $i/$MaxRetries): $errorDetails"
            
            if ($i -lt $MaxRetries) {
                Write-Verbose "Waiting $RetryDelay seconds before retry..."
                
                if ($OnRetry) {
                    Write-Verbose 'Executing OnRetry script block...'
                    & $OnRetry
                }
                
                Start-Sleep -Seconds $RetryDelay
            }
            else {
                Write-Warning "$ErrorMessage after $MaxRetries attempts: $errorDetails"
            }
        }
    }
    
    return $null
}

function Wait-WithProgress {
    <#
    .SYNOPSIS
        Waits for a specified duration with optional progress display.
    
    .PARAMETER Seconds
        Number of seconds to wait.
    
    .PARAMETER Activity
        Activity description for progress bar.
    
    .PARAMETER ShowProgress
        Show a progress indicator while waiting.
    
    .EXAMPLE
        Wait-WithProgress -Seconds 5 -Activity "Network Stabilization" -ShowProgress
    
    .EXAMPLE
        Wait-WithProgress -Seconds 3
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Seconds,
        
        [Parameter()]
        [string]$Activity = 'Waiting',
        
        [Parameter()]
        [switch]$ShowProgress
    )
    
    if ($ShowProgress) {
        for ($i = 1; $i -le $Seconds; $i++) {
            $percentComplete = ($i / $Seconds) * 100
            Write-Progress -Activity $Activity -Status "Waiting... ($i/$Seconds seconds)" -PercentComplete $percentComplete
            Start-Sleep -Seconds 1
        }
        Write-Progress -Activity $Activity -Completed
    }
    else {
        Start-Sleep -Seconds $Seconds
    }
}

Export-ModuleMember -Function @(
    'Invoke-WithRetry',
    'Wait-WithProgress'
)
