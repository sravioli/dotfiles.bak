<#
.SYNOPSIS
    Universal task creation and management script for PowerShell profile events.

.DESCRIPTION
    This script automatically discovers event folders in the Tasks directory and creates
    Windows scheduled tasks based on configuration. Each event folder must contain:
    - Run.ps1 (required): The script to execute
    - README.md (recommended): Documentation for the task
    - task.config.json (optional): Task-specific configuration overrides
    - .env (optional): Environment variables

.PARAMETER Action
    The action to perform: Create, Remove, List, or Validate

.PARAMETER FolderName
    Specific folder name to process. If not specified, processes all folders.

.PARAMETER Force
    Force recreation of existing tasks.

.PARAMETER WhatIf
    Shows what would be done without making changes.

.EXAMPLE
    .\Create.ps1 -Action Create
    Creates tasks for all valid event folders.

.EXAMPLE
    .\Create.ps1 -Action Create -FolderName "wlan-autoconfig" -Force
    Recreates the task for the wlan-autoconfig event.

.EXAMPLE
    .\Create.ps1 -Action List
    Lists all managed tasks and their status.

.EXAMPLE
    .\Create.ps1 -Action Validate
    Validates all event folders for required files and proper structure.

.NOTES
    Author: Task Management System
    Version: 1.0.0
    Requires: PowerShell 7+, Administrator privileges
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Create', 'Remove', 'List', 'Validate')]
    [string]$Action = 'Create',
    
    [Parameter(Position = 1)]
    [string]$FolderName,
    
    [Parameter()]
    [switch]$Force
)

#region Initialization

# Change to script directory
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
Push-Location $ScriptDirectory
Write-Verbose "Working directory set to: $ScriptDirectory"

#endregion

#region Helper Functions

function Write-ColorOutput {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Verbose')]
        [string]$Level = 'Info'
    )
    
    $colors = @{
        Info    = 'Cyan'
        Success = 'Green'
        Warning = 'Yellow'
        Error   = 'Red'
        Verbose = 'Gray'
    }
    
    $icons = @{
        Info    = '[i]'
        Success = '[√]'
        Warning = '[!]'
        Error   = '[X]'
        Verbose = '[?]'
    }
    
    Write-Host "$($icons[$Level]) $Message" -ForegroundColor $colors[$Level]
}

function Get-TaskConfiguration {
    <#
    .SYNOPSIS
        Builds the complete task configuration by merging defaults and overrides.
    #>
    param(
        [string]$TaskFolderPath,
        [string]$FolderName
    )
    
    # 1. Built-in defaults
    $builtInDefaults = @{
        trigger             = @{
            type     = 'event'
            eventLog = 'Application'
            eventId  = 1
            provider = 'Application'
        }
        principal           = @{
            userId    = $env:USERNAME
            logonType = 'Interactive'
            runLevel  = 'Limited'
        }
        settings            = @{
            allowStartIfOnBatteries    = $true
            dontStopIfGoingOnBatteries = $true
            startWhenAvailable         = $true
            dontStopOnIdleEnd          = $true
            executionTimeLimit         = 'PT1H'
            hidden                     = $true
        }
        execution           = @{
            executable          = 'pwsh.exe'
            baseArguments       = '-NonInteractive -NoLogo -NoProfileLoadTime -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden'
            additionalArguments = ''
        }
        taskNameTemplate    = 'ProfileTask_{FolderName}'
        descriptionTemplate = 'Automated task for {FolderName} event'
    }
    
    # 2. Load global defaults if they exist
    $globalDefaultsPath = Join-Path $PSScriptRoot '.defaults.json'
    if (Test-Path $globalDefaultsPath) {
        try {
            $globalDefaults = Get-Content $globalDefaultsPath -Raw | ConvertFrom-Json -AsHashtable
            $builtInDefaults = Merge-Hashtables $builtInDefaults $globalDefaults
            Write-Verbose 'Loaded global defaults from .defaults.json'
        }
        catch {
            Write-ColorOutput "Failed to load global defaults: $_" -Level Warning
        }
    }
    
    # 3. Load task-specific config if it exists
    $taskConfigPath = Join-Path $TaskFolderPath 'task.config.json'
    if (Test-Path $taskConfigPath) {
        try {
            $taskConfig = Get-Content $taskConfigPath -Raw | ConvertFrom-Json -AsHashtable
            $builtInDefaults = Merge-Hashtables $builtInDefaults $taskConfig
            Write-Verbose 'Loaded task-specific config from task.config.json'
        }
        catch {
            Write-ColorOutput "Failed to load task config: $_" -Level Warning
        }
    }
    
    # 4. Apply template variables
    $config = $builtInDefaults
    $config.taskName = $config.taskNameTemplate -replace '\{FolderName\}', $FolderName
    $config.description = $config.descriptionTemplate -replace '\{FolderName\}', $FolderName
    $config.folderPath = $TaskFolderPath
    $config.runScriptPath = Join-Path $TaskFolderPath 'Run.ps1'
    
    return $config
}

function Merge-Hashtables {
    <#
    .SYNOPSIS
        Deep merges two hashtables, with the second overriding the first.
    #>
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )
    
    $result = $Base.Clone()
    
    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-Hashtables $result[$key] $Override[$key]
        }
        else {
            $result[$key] = $Override[$key]
        }
    }
    
    return $result
}

function Test-EventFolder {
    <#
    .SYNOPSIS
        Validates an event folder has all required files.
    #>
    param(
        [System.IO.DirectoryInfo]$Folder
    )
    
    $validationResult = @{
        IsValid   = $true
        IsSkipped = $false
        Errors    = @()
        Warnings  = @()
        Path      = $Folder.FullName
        Name      = $Folder.Name
    }
    
    # Check for skip file
    $skipFiles = @('.skip', '!skip', 'skip')
    foreach ($skipFile in $skipFiles) {
        if (Test-Path (Join-Path $Folder.FullName $skipFile)) {
            $validationResult.IsSkipped = $true
            $validationResult.Warnings += "Folder marked to skip (found $skipFile)"
            return $validationResult
        }
    }
    
    # Check for required files
    $runScript = Join-Path $Folder.FullName 'Run.ps1'
    if (-not (Test-Path $runScript)) {
        $validationResult.IsValid = $false
        $validationResult.Errors += 'Missing required file: Run.ps1'
    }
    
    # Check for preferred files
    $readme = Join-Path $Folder.FullName 'README.md'
    if (-not (Test-Path $readme)) {
        $validationResult.Warnings += 'No README.md found (recommended for documentation)'
    }
    
    # Check for optional files (just for info)
    $envFile = Join-Path $Folder.FullName '.env'
    if (-not (Test-Path $envFile)) {
        $validationResult.Warnings += 'No .env file found (optional)'
    }
    
    $configFile = Join-Path $Folder.FullName 'task.config.json'
    if (-not (Test-Path $configFile)) {
        $validationResult.Warnings += 'No task.config.json found (will use defaults)'
    }
    
    return $validationResult
}

function New-ScheduledTaskFromConfig {
    <#
    .SYNOPSIS
        Creates a Windows scheduled task from configuration.
    #>
    param(
        [hashtable]$Config,
        [switch]$Force
    )
    
    $taskName = $Config.taskName
    
    # Check if task exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($existingTask -and -not $Force) {
        Write-ColorOutput "Task '$taskName' already exists. Use -Force to recreate." -Level Warning
        return $false
    }
    
    if ($existingTask -and $Force) {
        Write-Verbose "Removing existing task '$taskName'"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    try {
        # Build action arguments
        $arguments = "$($Config.execution.baseArguments) -File `"$($Config.runScriptPath)`""
        if ($Config.execution.additionalArguments) {
            $arguments += " $($Config.execution.additionalArguments)"
        }
        
        # Create action
        $action = New-ScheduledTaskAction `
            -Execute $Config.execution.executable `
            -Argument $arguments `
            -WorkingDirectory (Split-Path $Config.runScriptPath -Parent)
        
        # Create trigger based on type
        $trigger = $null
        switch ($Config.trigger.type) {
            'event' {
                try {
                    $triggerClass = Get-CimClass -Namespace Root/Microsoft/Windows/TaskScheduler -ClassName MSFT_TaskEventTrigger -ErrorAction Stop
                    
                    if (-not $triggerClass) {
                        throw 'Failed to get MSFT_TaskEventTrigger CIM class'
                    }
                    
                    $trigger = New-CimInstance -CimClass $triggerClass -ClientOnly -ErrorAction Stop
                    
                    if (-not $trigger) {
                        throw 'Failed to create CIM instance for event trigger'
                    }
                    
                    $trigger.Enabled = $true
                    
                    # Build event subscription XML
                    $subscription = @"
<QueryList>
  <Query Id="0" Path="$($Config.trigger.eventLog)">
    <Select Path="$($Config.trigger.eventLog)">
      *[System[Provider[@Name='$($Config.trigger.provider)'] and EventID=$($Config.trigger.eventId)]]
    </Select>
  </Query>
</QueryList>
"@
                    $trigger.Subscription = $subscription
                    
                    Write-Verbose 'Event trigger created successfully'
                }
                catch {
                    throw "Failed to create event trigger: $_"
                }
            }
            'time' {
                $trigger = New-ScheduledTaskTrigger `
                    -Once `
                    -At (Get-Date) `
                    -RepetitionInterval (New-TimeSpan -Minutes ($Config.trigger.intervalMinutes ?? 5))
            }
            'logon' {
                $trigger = New-ScheduledTaskTrigger -AtLogOn
            }
            'startup' {
                $trigger = New-ScheduledTaskTrigger -AtStartup
            }
            default {
                throw "Unsupported trigger type: $($Config.trigger.type)"
            }
        }
        
        # Create principal
        $principalParams = @{
            UserId    = $Config.principal.userId
            LogonType = $Config.principal.logonType
            RunLevel  = $Config.principal.runLevel
        }
        $principal = New-ScheduledTaskPrincipal @principalParams
        
        # Create settings
        $settingsParams = @{}
        foreach ($key in $Config.settings.Keys) {
            $settingsParams[$key] = $Config.settings[$key]
        }
        $settings = New-ScheduledTaskSettingsSet @settingsParams
        
        # Create task - always include trigger in task params
        $taskParams = @{
            Action      = $action
            Trigger     = $trigger
            Principal   = $principal
            Settings    = $settings
            Description = $Config.description
        }
        
        $task = New-ScheduledTask @taskParams
        Write-Verbose 'Scheduled task object created successfully'
        
        # Register task
        Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
        
        Write-ColorOutput "Successfully created task: $taskName" -Level Success
        return $true
    }
    catch {
        Write-ColorOutput "Failed to create task '$taskName': $_" -Level Error
        Write-Verbose "Error details: $($_.Exception.Message)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        
        # Provide helpful hints for common issues
        if ($_.Exception.Message -like '*null-valued expression*') {
            Write-ColorOutput '  Hint: This usually means the trigger creation failed. Check your task.config.json trigger settings.' -Level Warning
        }
        elseif ($_.Exception.Message -like '*TimeSpan*') {
            Write-ColorOutput "  Hint: executionTimeLimit must use HH:MM:SS format (e.g., '00:05:00'), not ISO 8601 (e.g., 'PT5M')" -Level Warning
        }
        
        return $false
    }
}

function Remove-ManagedTask {
    <#
    .SYNOPSIS
        Removes a managed scheduled task.
    #>
    param(
        [string]$TaskName
    )
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    if (-not $task) {
        Write-ColorOutput "Task '$TaskName' not found." -Level Warning
        return $false
    }
    
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-ColorOutput "Successfully removed task: $TaskName" -Level Success
        return $true
    }
    catch {
        Write-ColorOutput "Failed to remove task '$TaskName': $_" -Level Error
        return $false
    }
}

function Get-EventFolders {
    <#
    .SYNOPSIS
        Gets all event folders in the Tasks directory.
    #>
    param(
        [string]$SpecificFolder
    )
    
    if ($SpecificFolder) {
        $folderPath = Join-Path $PSScriptRoot $SpecificFolder
        if (Test-Path $folderPath) {
            return @(Get-Item $folderPath)
        }
        else {
            Write-ColorOutput "Folder not found: $SpecificFolder" -Level Error
            return @()
        }
    }
    
    return Get-ChildItem -Path $PSScriptRoot -Directory | Where-Object {
        $_.Name -ne 'Help' -and $_.Name -ne 'Backup'
    }
}

#endregion

#region Main Actions

function Invoke-CreateTasks {
    param(
        [string]$SpecificFolder,
        [switch]$Force
    )
    
    Write-ColorOutput 'Starting task creation process...' -Level Info
    Write-Host ''
    
    $folders = Get-EventFolders -SpecificFolder $SpecificFolder
    $successCount = 0
    $skipCount = 0
    $failCount = 0
    
    foreach ($folder in $folders) {
        Write-ColorOutput "Processing folder: $($folder.Name)" -Level Verbose
        
        # Validate folder
        $validation = Test-EventFolder -Folder $folder
        
        if ($validation.IsSkipped) {
            Write-ColorOutput "  Skipping: $($folder.Name)" -Level Warning
            $skipCount++
            continue
        }
        
        if (-not $validation.IsValid) {
            Write-ColorOutput "  Invalid folder: $($folder.Name)" -Level Error
            foreach ($err in $validation.Errors) {
                Write-ColorOutput "    - $err" -Level Error
            }
            $failCount++
            continue
        }
        
        # Show warnings
        foreach ($warning in $validation.Warnings) {
            Write-ColorOutput "  $warning" -Level Warning
        }
        
        # Get configuration
        $config = Get-TaskConfiguration -TaskFolderPath $folder.FullName -FolderName $folder.Name
        
        # Create task
        if ($PSCmdlet.ShouldProcess($config.taskName, 'Create scheduled task')) {
            $result = New-ScheduledTaskFromConfig -Config $config -Force:$Force
            if ($result) {
                $successCount++
            }
            else {
                $failCount++
            }
        }
        
        Write-Host ''
    }
    
    # Summary
    Write-ColorOutput 'Task creation complete!' -Level Info
    Write-Host "  [√] Created: $successCount" -ForegroundColor Green
    Write-Host "  [>] Skipped: $skipCount" -ForegroundColor Yellow
    Write-Host "  [X] Failed: $failCount" -ForegroundColor Red
}

function Invoke-RemoveTasks {
    param(
        [string]$SpecificFolder
    )
    
    Write-ColorOutput 'Starting task removal process...' -Level Info
    Write-Host ''
    
    $folders = Get-EventFolders -SpecificFolder $SpecificFolder
    $successCount = 0
    $failCount = 0
    
    foreach ($folder in $folders) {
        $config = Get-TaskConfiguration -TaskFolderPath $folder.FullName -FolderName $folder.Name
        
        if ($PSCmdlet.ShouldProcess($config.taskName, 'Remove scheduled task')) {
            $result = Remove-ManagedTask -TaskName $config.taskName
            if ($result) {
                $successCount++
            }
            else {
                $failCount++
            }
        }
    }
    
    # Summary
    Write-ColorOutput 'Task removal complete!' -Level Info
    Write-Host "  [√] Removed: $successCount" -ForegroundColor Green
    Write-Host "  [X] Failed: $failCount" -ForegroundColor Red
}

function Invoke-ListTasks {
    Write-ColorOutput 'Listing all managed tasks...' -Level Info
    Write-Host ''
    
    $folders = Get-EventFolders
    $tasks = @()
    
    foreach ($folder in $folders) {
        $validation = Test-EventFolder -Folder $folder
        if ($validation.IsSkipped -or -not $validation.IsValid) {
            continue
        }
        
        $config = Get-TaskConfiguration -TaskFolderPath $folder.FullName -FolderName $folder.Name
        $scheduledTask = Get-ScheduledTask -TaskName $config.taskName -ErrorAction SilentlyContinue
        
        $tasks += [PSCustomObject]@{
            Folder      = $folder.Name
            TaskName    = $config.taskName
            Status      = if ($scheduledTask) { $scheduledTask.State } else { 'Not Created' }
            Trigger     = $config.trigger.type
            LastRunTime = if ($scheduledTask) { (Get-ScheduledTaskInfo -TaskName $config.taskName).LastRunTime } else { 'N/A' }
            NextRunTime = if ($scheduledTask) { (Get-ScheduledTaskInfo -TaskName $config.taskName).NextRunTime } else { 'N/A' }
        }
    }
    
    if ($tasks.Count -eq 0) {
        Write-ColorOutput 'No managed tasks found.' -Level Warning
    }
    else {
        $tasks | Format-Table -AutoSize
    }
}

function Invoke-ValidateFolders {
    param(
        [string]$SpecificFolder
    )
    
    Write-ColorOutput 'Validating event folders...' -Level Info
    Write-Host ''
    
    $folders = Get-EventFolders -SpecificFolder $SpecificFolder
    $validCount = 0
    $invalidCount = 0
    $skippedCount = 0
    $firstFolder = $true
    
    foreach ($folder in $folders) {
        $validation = Test-EventFolder -Folder $folder
        
        # Add line break before each folder except the first
        if (-not $firstFolder) {
            Write-Host
        }
        $firstFolder = $false
        
        # Print folder name and status on same line
        if ($validation.IsSkipped) {
            Write-Host "$($folder.Name): " -ForegroundColor Cyan -NoNewline
            Write-Host '[>] Skipped' -ForegroundColor Yellow
            $skippedCount++
        }
        elseif ($validation.IsValid) {
            Write-Host "$($folder.Name): " -ForegroundColor Cyan -NoNewline
            Write-Host '[√] Valid' -ForegroundColor Green
            $validCount++
        }
        else {
            Write-Host "$($folder.Name): " -ForegroundColor Cyan -NoNewline
            Write-Host '[X] Invalid' -ForegroundColor Red
            $invalidCount++
        }
        
        # Show errors and warnings without repeating symbols
        foreach ($err in $validation.Errors) {
            Write-Host "  - $err" -ForegroundColor Red
        }
        
        foreach ($warning in $validation.Warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
    }
    
    # Summary
    Write-Host ''
    Write-ColorOutput 'Validation complete!' -Level Info
    Write-Host "  [√] Valid: $validCount" -ForegroundColor Green
    Write-Host "  [>] Skipped: $skippedCount" -ForegroundColor Yellow
    Write-Host "  [X] Invalid: $invalidCount" -ForegroundColor Red
}

#endregion

#endregion

#region Main Execution

# Check for administrator privileges for actions that need them
function Test-IsAdministrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main script execution
try {
    # Actions that require admin
    $adminRequiredActions = @('Create', 'Remove')
    
    if ($Action -in $adminRequiredActions -and -not (Test-IsAdministrator)) {
        Write-ColorOutput "Action '$Action' requires administrator privileges." -Level Error
        Write-ColorOutput 'Please run PowerShell as Administrator and try again.' -Level Warning
        exit 1
    }
    
    switch ($Action) {
        'Create' {
            Invoke-CreateTasks -SpecificFolder $FolderName -Force:$Force
        }
        'Remove' {
            Invoke-RemoveTasks -SpecificFolder $FolderName
        }
        'List' {
            Invoke-ListTasks
        }
        'Validate' {
            Invoke-ValidateFolders -SpecificFolder $FolderName
        }
    }
}
catch {
    Write-ColorOutput "An error occurred: $_" -Level Error
    Write-ColorOutput $_.ScriptStackTrace -Level Error
    exit 1
}
finally {
    # Restore original directory
    Pop-Location
}

#endregion
