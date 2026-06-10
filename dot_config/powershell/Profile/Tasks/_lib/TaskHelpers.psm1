<#
.SYNOPSIS
    Main module for PowerShell task utilities.

.DESCRIPTION
    This module aggregates all task helper functionality by importing specialized sub-modules.
    It provides a unified interface for:
    - Environment variable loading
    - Structured logging
    - Application/process management
    - Configuration validation
    - Network utilities
    - Retry logic
    - Credential management
    - UI automation

.NOTES
    Author: Task Management System
    Version: 2.0.0
    Last Updated: 2025-11-11
    
.ARCHITECTURE
    This module follows separation of concerns by dividing functionality into focused sub-modules:
    
    - TaskEnvironment.psm1    : Environment variable management (.env files)
    - TaskLogging.psm1        : Structured logging with severity levels
    - WindowHelper.psm1       : Windows API for window management
    - RetryHelper.psm1        : Generic retry and wait logic
    - ProcessManager.psm1     : Application launching and process detection
    - ConfigValidation.psm1   : Configuration variable validation
    - NetworkHelper.psm1      : Network profile detection
    - CredentialHelper.psm1   : Windows Credential Manager integration
    - UIAutomation.psm1       : SendKeys and Outlook OTP extraction
#>

$ErrorActionPreference = 'Stop'

# Get the module directory
$ModuleRoot = $PSScriptRoot

# Import all sub-modules in dependency order
$subModules = @(
    'TaskLogging.psm1'         # Core logging (no dependencies)
    'TaskEnvironment.psm1'     # Environment loading (no dependencies)
    'WindowHelper.psm1'        # Windows API (no dependencies)
    'RetryHelper.psm1'         # Retry logic (no dependencies)
    'ProcessManager.psm1'      # Process management (depends on: Logging, WindowHelper)
    'ConfigValidation.psm1'    # Config validation (depends on: Logging)
    'NetworkHelper.psm1'       # Network utilities (depends on: Logging, RetryHelper)
    'CredentialHelper.psm1'    # Credential management (depends on: Logging)
    'UIAutomation.psm1'        # UI automation (no dependencies)
)

foreach ($module in $subModules) {
    $modulePath = Join-Path $ModuleRoot $module
    
    if (Test-Path $modulePath) {
        Write-Verbose "Importing sub-module: $module"
        # Import without -Global to avoid scope issues
        Import-Module $modulePath -Force -DisableNameChecking
    }
    else {
        Write-Warning "Sub-module not found: $modulePath"
    }
}

# Re-export all functions from sub-modules for convenience
$exportedFunctions = @(
    # Environment (TaskEnvironment.psm1)
    'Import-TaskEnvironment'
    
    # Logging (TaskLogging.psm1)
    'Write-TaskLog'
    'Write-TaskSeparator'
    
    # Window Management (WindowHelper.psm1)
    'Set-WindowForeground'
    'Show-Window'
    
    # Retry Logic (RetryHelper.psm1)
    'Invoke-WithRetry'
    'Wait-WithProgress'
    
    # Process Management (ProcessManager.psm1)
    'Start-ApplicationWithRetry'
    'Test-ProcessRunning'
    'Set-ApplicationWindowFocus'
    
    # Configuration (ConfigValidation.psm1)
    'Test-RequiredVariables'
    'Write-ConfigurationSummary'
    
    # Network (NetworkHelper.psm1)
    'Get-WifiConnectionProfile'
    'Test-WifiConnected'
    'Wait-NetworkStabilization'
    
    # Credentials (CredentialHelper.psm1)
    'Save-SecureCredential'
    'Get-SecureCredential'
    'Remove-SecureCredential'
    
    # UI Automation (UIAutomation.psm1)
    'Send-Keys'
    'Get-OutlookOTP'
)

$exportedAliases = @(
    'dotenv'  # Alias for Import-TaskEnvironment
)

# Export all functions and aliases
Export-ModuleMember -Function $exportedFunctions -Alias $exportedAliases

Write-Verbose "TaskHelpers module loaded successfully (v2.0.0)"
