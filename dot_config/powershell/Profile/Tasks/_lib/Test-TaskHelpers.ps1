<#
.SYNOPSIS
    Test script for TaskHelpers v2 module.

.DESCRIPTION
    Verifies that all functions from the refactored modules are accessible.
#>

[CmdletBinding()]
param()

Write-Host "Testing TaskHelpers v2 Module..." -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

# Import the module
$modulePath = Join-Path $PSScriptRoot 'TaskHelpers_v2.psm1'
Write-Host "`nImporting module: $modulePath" -ForegroundColor Yellow

try {
    Import-Module $modulePath -Force -Verbose:$false
    Write-Host "✓ Module imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to import module: $_" -ForegroundColor Red
    exit 1
}

# Test functions from each sub-module
Write-Host "`nTesting exported functions..." -ForegroundColor Yellow

$functionsToTest = @(
    # TaskLogging
    'Write-TaskLog',
    'Write-TaskSeparator',
    
    # TaskEnvironment
    'Import-TaskEnvironment',
    
    # WindowHelper
    'Set-WindowForeground',
    'Show-Window',
    
    # RetryHelper
    'Invoke-WithRetry',
    'Wait-WithProgress',
    
    # ProcessManager
    'Start-ApplicationWithRetry',
    'Test-ProcessRunning',
    'Set-ApplicationWindowFocus',
    
    # ConfigValidation
    'Test-RequiredVariables',
    'Write-ConfigurationSummary',
    
    # NetworkHelper
    'Get-WifiConnectionProfile',
    'Test-WifiConnected',
    'Wait-NetworkStabilization',
    
    # CredentialHelper
    'Save-SecureCredential',
    'Get-SecureCredential',
    'Remove-SecureCredential',
    
    # UIAutomation
    'Send-Keys',
    'Get-OutlookOTP'
)

$missingFunctions = @()
$foundFunctions = @()

foreach ($function in $functionsToTest) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        $foundFunctions += $function
        Write-Host "  ✓ $function" -ForegroundColor Green
    }
    else {
        $missingFunctions += $function
        Write-Host "  ✗ $function (NOT FOUND)" -ForegroundColor Red
    }
}

# Test alias
Write-Host "`nTesting aliases..." -ForegroundColor Yellow
if (Get-Alias dotenv -ErrorAction SilentlyContinue) {
    Write-Host "  ✓ dotenv" -ForegroundColor Green
}
else {
    Write-Host "  ✗ dotenv (NOT FOUND)" -ForegroundColor Red
}

# Summary
Write-Host "`n" -NoNewline
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "`nTest Summary:" -ForegroundColor Cyan
Write-Host "  Total functions: $($functionsToTest.Count)" -ForegroundColor White
Write-Host "  Found: $($foundFunctions.Count)" -ForegroundColor Green
Write-Host "  Missing: $($missingFunctions.Count)" -ForegroundColor $(if ($missingFunctions.Count -eq 0) { 'Green' } else { 'Red' })

if ($missingFunctions.Count -eq 0) {
    Write-Host "`n✓ All tests passed!" -ForegroundColor Green
    
    # Quick functional test
    Write-Host "`nRunning functional tests..." -ForegroundColor Yellow
    
    try {
        Write-TaskLog "Test log message" -Level Info
        Write-TaskLog "Test success message" -Level Success
        Write-TaskSeparator -Character '-' -Length 40
        
        $testVars = Test-RequiredVariables -VariableNames @('HOME', 'USERNAME') -ErrorAction SilentlyContinue
        if ($testVars.IsValid) {
            Write-Host "  ✓ Configuration validation works" -ForegroundColor Green
        }
        
        Write-Host "`n✓ Functional tests passed!" -ForegroundColor Green
    }
    catch {
        Write-Host "`n✗ Functional test failed: $_" -ForegroundColor Red
    }
    
    exit 0
}
else {
    Write-Host "`n✗ Some functions are missing!" -ForegroundColor Red
    Write-Host "Missing functions:" -ForegroundColor Red
    $missingFunctions | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
