<#
.SYNOPSIS
    Windows API wrapper for window management.

.DESCRIPTION
    Provides Windows API functions for window manipulation (focus, restore, etc.)

.NOTES
    Author: Task Management System
    Version: 2.0.0
    Last Updated: 2025-11-11
#>

# Add Windows API types if not already defined
if (-not ([System.Management.Automation.PSTypeName]'WindowHelper').Type) {
    Add-Type @'
        using System;
        using System.Runtime.InteropServices;
        
        public class WindowHelper {
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool SetForegroundWindow(IntPtr hWnd);
            
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            
            public const int SW_RESTORE = 9;
            public const int SW_MINIMIZE = 6;
            public const int SW_MAXIMIZE = 3;
        }
'@ -ErrorAction SilentlyContinue
}

function Set-WindowForeground {
    <#
    .SYNOPSIS
        Brings a window to the foreground.
    
    .PARAMETER WindowHandle
        The window handle (IntPtr) to bring to foreground.
    
    .PARAMETER Restore
        Restore the window if minimized before bringing to foreground.
    
    .EXAMPLE
        $process = Get-Process -Name notepad
        Set-WindowForeground -WindowHandle $process.MainWindowHandle -Restore
    
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,
        
        [Parameter()]
        [switch]$Restore
    )
    
    if ($WindowHandle -eq [IntPtr]::Zero) {
        Write-Verbose 'Invalid window handle (Zero)'
        return $false
    }
    
    try {
        if ($Restore) {
            [WindowHelper]::ShowWindow($WindowHandle, [WindowHelper]::SW_RESTORE) | Out-Null
        }
        
        $result = [WindowHelper]::SetForegroundWindow($WindowHandle)
        Write-Verbose "SetForegroundWindow result: $result"
        return $result
    }
    catch {
        Write-Verbose "Failed to set window foreground: $_"
        return $false
    }
}

function Show-Window {
    <#
    .SYNOPSIS
        Shows or hides a window with specified state.
    
    .PARAMETER WindowHandle
        The window handle (IntPtr).
    
    .PARAMETER State
        Window state: Restore, Minimize, Maximize.
    
    .EXAMPLE
        Show-Window -WindowHandle $handle -State Restore
    
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,
        
        [Parameter(Mandatory)]
        [ValidateSet('Restore', 'Minimize', 'Maximize')]
        [string]$State
    )
    
    if ($WindowHandle -eq [IntPtr]::Zero) {
        Write-Verbose 'Invalid window handle (Zero)'
        return $false
    }
    
    $stateCode = switch ($State) {
        'Restore' { [WindowHelper]::SW_RESTORE }
        'Minimize' { [WindowHelper]::SW_MINIMIZE }
        'Maximize' { [WindowHelper]::SW_MAXIMIZE }
    }
    
    try {
        $result = [WindowHelper]::ShowWindow($WindowHandle, $stateCode)
        Write-Verbose "ShowWindow($State) result: $result"
        return $result
    }
    catch {
        Write-Verbose "Failed to show window: $_"
        return $false
    }
}

Export-ModuleMember -Function @(
    'Set-WindowForeground',
    'Show-Window'
)
