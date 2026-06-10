<#
.SYNOPSIS
    Configuration validation helpers for PowerShell tasks.

.DESCRIPTION
    Provides functions to validate and display configuration settings.

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

function Test-RequiredVariables {
    <#
    .SYNOPSIS
        Validates that required variables are defined.
    
    .DESCRIPTION
        Checks if specified variables exist in the given scope.
        Returns validation results with missing variable details.
    
    .PARAMETER VariableNames
        Array of variable names to check.
    
    .PARAMETER Scope
        Scope to check variables in. Default is 'Script'.
    
    .PARAMETER ThrowOnMissing
        Throw an error if any variables are missing.
    
    .EXAMPLE
        Test-RequiredVariables -VariableNames 'API_KEY', 'SERVER_URL'
    
    .EXAMPLE
        $result = Test-RequiredVariables -VariableNames @('VAR1', 'VAR2')
        if (-not $result.IsValid) { 
            Write-Error "Missing: $($result.MissingVariables -join ', ')"
        }
    
    .OUTPUTS
        PSCustomObject with IsValid, MissingVariables, FoundVariables, and TotalChecked properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$VariableNames,
        
        [Parameter()]
        [ValidateSet('Script', 'Local', 'Global')]
        [string]$Scope = 'Script',
        
        [Parameter()]
        [switch]$ThrowOnMissing
    )
    
    $missingVars = @()
    $foundVars = @()
    
    foreach ($varName in $VariableNames) {
        try {
            $value = Get-Variable -Name $varName -Scope $Scope -ValueOnly -ErrorAction Stop
            
            if ([string]::IsNullOrWhiteSpace($value)) {
                $missingVars += $varName
                Write-TaskLog "Variable '$varName' is empty or whitespace" -Level Warning
            }
            else {
                $foundVars += $varName
                Write-Verbose "Variable '$varName' is defined"
            }
        }
        catch {
            $missingVars += $varName
            Write-TaskLog "Variable '$varName' is not defined" -Level Warning
        }
    }
    
    $result = [PSCustomObject]@{
        IsValid          = $missingVars.Count -eq 0
        MissingVariables = $missingVars
        FoundVariables   = $foundVars
        TotalChecked     = $VariableNames.Count
    }
    
    if ($ThrowOnMissing -and -not $result.IsValid) {
        throw "Missing required variables: $($missingVars -join ', ')"
    }
    
    return $result
}

function Write-ConfigurationSummary {
    <#
    .SYNOPSIS
        Writes a formatted configuration summary to the log.
    
    .PARAMETER Variables
        Hashtable of variable names and values to display.
    
    .PARAMETER Title
        Title for the configuration section. Default is 'Configuration'.
    
    .PARAMETER MaskSecrets
        Mask values that contain common secret keywords.
    
    .PARAMETER SecretKeywords
        Custom array of keywords to identify secret values. 
        Default: @('password', 'secret', 'key', 'token', 'credential')
    
    .EXAMPLE
        Write-ConfigurationSummary -Variables @{ SSID='MyNetwork'; API_KEY='secret123' } -MaskSecrets
    
    .EXAMPLE
        $config = @{
            ServerUrl = 'https://api.example.com'
            Username = 'admin'
            ApiToken = 'token123'
        }
        Write-ConfigurationSummary -Variables $config -Title "API Configuration" -MaskSecrets
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Variables,
        
        [Parameter()]
        [string]$Title = 'Configuration',
        
        [Parameter()]
        [switch]$MaskSecrets,
        
        [Parameter()]
        [string[]]$SecretKeywords = @('password', 'secret', 'key', 'token', 'credential')
    )
    
    Write-TaskLog "${Title}:" -Level Info
    
    if ($Variables.Count -eq 0) {
        Write-TaskLog '  (No configuration items)' -Level Info
        return
    }
    
    foreach ($key in ($Variables.Keys | Sort-Object)) {
        $value = $Variables[$key]
        
        if ($MaskSecrets -and $value) {
            $shouldMask = $SecretKeywords | Where-Object { $key -like "*$_*" }
            if ($shouldMask) {
                $value = '***MASKED***'
            }
        }
        
        Write-TaskLog "  $key = $value" -Level Info
    }
}

Export-ModuleMember -Function @(
    'Test-RequiredVariables',
    'Write-ConfigurationSummary'
)
