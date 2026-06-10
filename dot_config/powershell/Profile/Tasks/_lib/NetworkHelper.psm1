<#
.SYNOPSIS
    Network utilities for PowerShell tasks.

.DESCRIPTION
    Provides functions for network profile detection and management.

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
if (-not (Get-Command Wait-WithProgress -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $libPath 'RetryHelper.psm1') -Force -DisableNameChecking
}

function Get-WifiConnectionProfile {
    <#
    .SYNOPSIS
        Gets the current Wi-Fi connection profile.
    
    .DESCRIPTION
        Retrieves the active Wi-Fi network connection profile information.
    
    .PARAMETER InterfacePattern
        Pattern to match interface aliases. Default is 'Wi-Fi*'.
    
    .EXAMPLE
        $wifi = Get-WifiConnectionProfile
        if ($wifi) { Write-Host "Connected to: $($wifi.Name)" }
    
    .EXAMPLE
        $wifi = Get-WifiConnectionProfile -InterfacePattern 'WLAN*'
    
    .OUTPUTS
        NetConnectionProfile object or $null if no Wi-Fi connection
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$InterfacePattern = @('Wi-Fi*', 'WLAN*')
    )
    
    $wifiProfile = Get-NetConnectionProfile | Where-Object { 
        $interface = $_.InterfaceAlias
        $InterfacePattern | Where-Object { $interface -like $_ }
    } | Select-Object -First 1
    
    if ($wifiProfile) {
        Write-Verbose "Found Wi-Fi profile: $($wifiProfile.Name) on $($wifiProfile.InterfaceAlias)"
    }
    else {
        Write-Verbose "No Wi-Fi connection found"
    }
    
    return $wifiProfile
}

function Test-WifiConnected {
    <#
    .SYNOPSIS
        Tests if connected to a specific Wi-Fi network.
    
    .PARAMETER SSID
        Network SSID to check for.
    
    .PARAMETER InterfacePattern
        Interface pattern(s) to check. Default is 'Wi-Fi*' and 'WLAN*'.
    
    .EXAMPLE
        if (Test-WifiConnected -SSID "HomeNetwork") {
            Write-Host "Connected to home network"
        }
    
    .EXAMPLE
        if (Test-WifiConnected -SSID "OfficeWiFi") {
            # Do office-specific tasks
        }
    
    .OUTPUTS
        Boolean indicating if connected to specified network
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SSID,
        
        [Parameter()]
        [string[]]$InterfacePattern = @('Wi-Fi*', 'WLAN*')
    )
    
    $wifiProfile = Get-WifiConnectionProfile -InterfacePattern $InterfacePattern
    
    if (-not $wifiProfile) {
        Write-Verbose 'No Wi-Fi connection detected'
        return $false
    }
    
    $isConnected = $wifiProfile.Name -eq $SSID
    
    if ($isConnected) {
        Write-Verbose "Connected to Wi-Fi network: $SSID"
    }
    else {
        Write-Verbose "Connected to different network: $($wifiProfile.Name)"
    }
    
    return $isConnected
}

function Wait-NetworkStabilization {
    <#
    .SYNOPSIS
        Waits for network to stabilize after connection.
    
    .PARAMETER Seconds
        Number of seconds to wait. Default is 3.
    
    .PARAMETER ShowProgress
        Show a progress indicator while waiting.
    
    .EXAMPLE
        Wait-NetworkStabilization -Seconds 5 -ShowProgress
    
    .EXAMPLE
        Wait-NetworkStabilization
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Seconds = 3,
        
        [Parameter()]
        [switch]$ShowProgress
    )
    
    Write-TaskLog "Waiting $Seconds seconds for network to stabilize..." -Level Info
    
    Wait-WithProgress -Seconds $Seconds -Activity 'Network Stabilization' -ShowProgress:$ShowProgress
}

Export-ModuleMember -Function @(
    'Get-WifiConnectionProfile',
    'Test-WifiConnected',
    'Wait-NetworkStabilization'
)
