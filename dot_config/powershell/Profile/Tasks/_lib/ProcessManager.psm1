<#
.SYNOPSIS
    Process and application management for PowerShell tasks.

.DESCRIPTION
    Provides functions for starting, detecting, and managing application processes.

.NOTES
    Author: Task Management System
    Version: 2.0.0
    Last Updated: 2025-11-11
#>

# Import dependencies
$libPath = $PSScriptRoot
if (-not (Get-Command Write-TaskLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $libPath 'TaskLogging.psm1') -Force -DisableNameChecking
}
if (-not (Get-Command Set-WindowForeground -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $libPath 'WindowHelper.psm1') -Force -DisableNameChecking
}

function Test-ProcessRunning {
    <#
    .SYNOPSIS
        Checks if a process is currently running.
    
    .PARAMETER ProcessName
        Name of the process (without .exe extension). Can be an array.
    
    .PARAMETER Path
        Full path to the executable (will extract process name).
    
    .EXAMPLE
        Test-ProcessRunning -ProcessName "outlook"
    
    .EXAMPLE
        Test-ProcessRunning -ProcessName @("outlook", "olk")
    
    .EXAMPLE
        Test-ProcessRunning -Path "C:\Program Files\App\app.exe"
    
    .OUTPUTS
        Process object if found, $null otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string[]]$ProcessName,
        
        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [string]$Path
    )
    
    # Extract process name from path if needed
    if ($Path) {
        $ProcessName = @([System.IO.Path]::GetFileNameWithoutExtension($Path))
    }
    
    foreach ($name in $ProcessName) {
        # Try direct process lookup
        $process = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($process) {
            Write-Verbose "Found process: $name (PID: $($process[0].Id))"
            return $process
        }
        
        # Try CIM for cross-session processes
        try {
            $cimProcess = Get-CimInstance -ClassName Win32_Process -Filter "Name='${name}.exe'" -ErrorAction SilentlyContinue
            if ($cimProcess) {
                $process = Get-Process -Id $cimProcess.ProcessId -ErrorAction SilentlyContinue
                if ($process) {
                    Write-Verbose "Found process via CIM: $name (PID: $($process.Id))"
                    return $process
                }
            }
        }
        catch {
            Write-Verbose "CIM lookup failed for ${name}: $_"
        }
    }
    
    return $null
}

function Set-ApplicationWindowFocus {
    <#
    .SYNOPSIS
        Attempts to focus an application window.
    
    .PARAMETER Process
        Process object(s) to focus.
    
    .PARAMETER ApplicationName
        Friendly name for logging.
    
    .EXAMPLE
        $proc = Get-Process -Name notepad
        Set-ApplicationWindowFocus -Process $proc -ApplicationName "Notepad"
    
    .OUTPUTS
        Boolean indicating if window was focused
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process[]]$Process,
        
        [Parameter()]
        [string]$ApplicationName = 'Application'
    )
    
    foreach ($proc in $Process) {
        $mainWindowHandle = $proc.MainWindowHandle
        
        if ($mainWindowHandle -ne [IntPtr]::Zero) {
            $focused = Set-WindowForeground -WindowHandle $mainWindowHandle -Restore
            
            if ($focused) {
                Write-TaskLog "Focused '$ApplicationName' window (PID: $($proc.Id))" -Level Success
                return $true
            }
        }
        else {
            Write-Verbose "Process $($proc.Id) has no main window"
        }
    }
    
    Write-Verbose "No focusable window found for $ApplicationName"
    return $false
}

function Start-ApplicationWithRetry {
    <#
    .SYNOPSIS
        Starts an application with retry logic and duplicate detection.
    
    .DESCRIPTION
        Attempts to launch an application with configurable retry logic.
        Checks if the application is already running before launching.
        Monitors process to verify successful start.
    
    .PARAMETER Path
        Full path to the application executable.
    
    .PARAMETER Name
        Friendly name for the application (for logging).
    
    .PARAMETER Arguments
        Command-line arguments to pass to the application.
    
    .PARAMETER MaxRetries
        Maximum number of launch attempts. Default is 3.
    
    .PARAMETER RetryDelay
        Delay in seconds between retry attempts. Default is 2.
    
    .PARAMETER SkipRunningCheck
        Skip checking if application is already running.
    
    .PARAMETER ProcessName
        The actual process name(s) to check for (without .exe). Can be an array.
        If not specified, will be extracted from Path.
    
    .EXAMPLE
        Start-ApplicationWithRetry -Path "C:\App\app.exe" -Name "MyApp"
    
    .EXAMPLE
        Start-ApplicationWithRetry -Path "outlook.exe" -Name "Outlook" -ProcessName @("outlook", "olk")
    
    .OUTPUTS
        Boolean indicating success or failure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [string]$Name,
        
        [Parameter()]
        [string]$Arguments,
        
        [Parameter()]
        [int]$MaxRetries = 3,
        
        [Parameter()]
        [int]$RetryDelay = 2,
        
        [Parameter()]
        [switch]$SkipRunningCheck,
        
        [Parameter()]
        [string[]]$ProcessName
    )
    
    # Determine friendly name
    $appName = if ($Name) { $Name } else { Split-Path $Path -Leaf }
    
    # Determine process names to check
    $targetProcessNames = if ($ProcessName -and $ProcessName.Count -gt 0) { 
        $ProcessName 
    }
    else { 
        @([System.IO.Path]::GetFileNameWithoutExtension($Path))
    }
    
    Write-Verbose "Target process name(s): $($targetProcessNames -join ', ')"
    
    # Check if already running
    if (-not $SkipRunningCheck) {
        $existingProcess = Test-ProcessRunning -ProcessName $targetProcessNames
        
        if ($existingProcess) {
            Write-TaskLog "'$appName' is already running (PID: $($existingProcess[0].Id))" -Level Info
            
            # Try to focus the window
            $focused = Set-ApplicationWindowFocus -Process $existingProcess -ApplicationName $appName
            
            if (-not $focused) {
                Write-TaskLog 'Application is running but has no main window to focus' -Level Info
            }
            
            return $true
        }
    }
    
    # Verify path exists
    if (-not (Test-Path $Path)) {
        Write-TaskLog "Application not found at: $Path" -Level Error
        return $false
    }
    
    # Launch with retries
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-TaskLog "Launching $appName (attempt $i/$MaxRetries)..." -Level Info
            
            $processParams = @{
                FilePath    = $Path
                PassThru    = $true
                ErrorAction = 'Stop'
            }
            
            if ($Arguments) {
                $processParams['ArgumentList'] = $Arguments
            }
            
            $process = Start-Process @processParams
            
            # Wait for application to initialize
            Start-Sleep -Milliseconds 500
            
            # Check if process is running
            $runningProcess = Test-ProcessRunning -ProcessName $targetProcessNames
            
            if ($runningProcess -or -not $process.HasExited) {
                $processId = if ($runningProcess) { $runningProcess[0].Id } else { $process.Id }
                Write-TaskLog "Successfully launched $appName (PID: $processId)" -Level Success
                return $true
            }
            elseif ($process.HasExited -and $process.ExitCode -eq 0) {
                # Launcher may have exited after starting real process
                Start-Sleep -Milliseconds 1500
                
                $runningProcess = Test-ProcessRunning -ProcessName $targetProcessNames
                
                if ($runningProcess) {
                    Write-TaskLog "Successfully launched $appName (PID: $($runningProcess[0].Id))" -Level Success
                    return $true
                }
                
                Write-TaskLog 'Process exited with code 0 but application not found' -Level Warning
            }
            else {
                Write-TaskLog "Process exited immediately (Exit Code: $($process.ExitCode))" -Level Warning
            }
        }
        catch {
            Write-TaskLog "Failed to launch $appName : $_" -Level Warning
        }
        
        if ($i -lt $MaxRetries) {
            Write-TaskLog "Waiting $RetryDelay seconds before retry..." -Level Info
            Start-Sleep -Seconds $RetryDelay
        }
    }
    
    Write-TaskLog "Failed to launch $appName after $MaxRetries attempts" -Level Error
    return $false
}

Export-ModuleMember -Function @(
    'Test-ProcessRunning',
    'Set-ApplicationWindowFocus',
    'Start-ApplicationWithRetry'
)
