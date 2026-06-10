<#
.SYNOPSIS
    Windows Credential Manager integration for PowerShell tasks.

.DESCRIPTION
    Provides secure credential storage and retrieval using Windows Credential Manager.

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

# Add Credential Manager API types if not already defined
if (-not ([System.Management.Automation.PSTypeName]'CredentialManager').Type) {
    Add-Type @'
        using System;
        using System.Runtime.InteropServices;
        using System.Text;
        
        public class CredentialManager {
            [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
            public struct CREDENTIAL {
                public int Flags;
                public int Type;
                public string TargetName;
                public string Comment;
                public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
                public int CredentialBlobSize;
                public IntPtr CredentialBlob;
                public int Persist;
                public int AttributeCount;
                public IntPtr Attributes;
                public string TargetAlias;
                public string UserName;
            }
            
            [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
            public static extern bool CredWrite([In] ref CREDENTIAL userCredential, [In] int flags);
            
            [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
            public static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);
            
            [DllImport("advapi32.dll", SetLastError = true)]
            public static extern bool CredFree([In] IntPtr cred);
            
            [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
            public static extern bool CredDelete(string target, int type, int reservedFlag);
        }
'@ -ErrorAction SilentlyContinue
}

function Save-SecureCredential {
    <#
    .SYNOPSIS
        Saves credentials to Windows Credential Manager.
    
    .DESCRIPTION
        Stores credentials securely using Windows Credential Manager.
        Credentials are encrypted and tied to the current user account.
    
    .PARAMETER Target
        Target name for the credential (e.g., "FortiClientVPN").
    
    .PARAMETER Username
        Username to store.
    
    .PARAMETER Password
        Password as SecureString. Use ConvertTo-SecureString to convert plain text.
    
    .EXAMPLE
        Save-SecureCredential -Target "MyApp" -Username "user@domain.com" -Password (Read-Host -AsSecureString)
    
    .EXAMPLE
        $pass = ConvertTo-SecureString "mypassword" -AsPlainText -Force
        Save-SecureCredential -Target "MyApp" -Username "user" -Password $pass
    
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target,
        
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [System.Security.SecureString]$Password
    )
    
    try {
        # Create PSCredential object
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        # Prepare credential for Windows API
        $passwordBytes = [System.Text.Encoding]::Unicode.GetBytes($credential.GetNetworkCredential().Password)
        $passwordPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($passwordBytes.Length)
        [System.Runtime.InteropServices.Marshal]::Copy($passwordBytes, 0, $passwordPtr, $passwordBytes.Length)
        
        $cred = New-Object CredentialManager+CREDENTIAL
        $cred.Type = 1  # CRED_TYPE_GENERIC
        $cred.TargetName = $Target
        $cred.UserName = $Username
        $cred.CredentialBlob = $passwordPtr
        $cred.CredentialBlobSize = $passwordBytes.Length
        $cred.Persist = 2  # CRED_PERSIST_LOCAL_MACHINE
        
        $result = [CredentialManager]::CredWrite([ref]$cred, 0)
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($passwordPtr)
        
        if ($result) {
            Write-TaskLog "Credential saved: $Target" -Level Success
            return $true
        }
        else {
            Write-TaskLog "Failed to save credential: $Target" -Level Error
            return $false
        }
    }
    catch {
        Write-TaskLog "Error saving credential: $_" -Level Error
        return $false
    }
}

function Get-SecureCredential {
    <#
    .SYNOPSIS
        Retrieves credentials from Windows Credential Manager.
    
    .PARAMETER Target
        Target name for the credential.
    
    .EXAMPLE
        $cred = Get-SecureCredential -Target "MyApp"
        if ($cred) {
            Write-Host "Username: $($cred.UserName)"
        }
    
    .OUTPUTS
        PSCredential object or $null if not found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )
    
    try {
        $credPtr = [IntPtr]::Zero
        $result = [CredentialManager]::CredRead($Target, 1, 0, [ref]$credPtr)
        
        if (-not $result) {
            Write-Verbose "Credential not found: $Target"
            return $null
        }
        
        $cred = [System.Runtime.InteropServices.Marshal]::PtrToStructure($credPtr, [type][CredentialManager+CREDENTIAL])
        
        $passwordBytes = New-Object byte[] $cred.CredentialBlobSize
        [System.Runtime.InteropServices.Marshal]::Copy($cred.CredentialBlob, $passwordBytes, 0, $cred.CredentialBlobSize)
        $password = [System.Text.Encoding]::Unicode.GetString($passwordBytes)
        
        [CredentialManager]::CredFree($credPtr)
        
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($cred.UserName, $securePassword)
        
        Write-Verbose "Retrieved credential for: $Target"
        return $credential
    }
    catch {
        Write-TaskLog "Error retrieving credential: $_" -Level Error
        return $null
    }
}

function Remove-SecureCredential {
    <#
    .SYNOPSIS
        Removes credentials from Windows Credential Manager.
    
    .PARAMETER Target
        Target name for the credential to remove.
    
    .EXAMPLE
        Remove-SecureCredential -Target "MyApp"
    
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )
    
    if (-not $PSCmdlet.ShouldProcess($Target, "Remove credential")) {
        return $false
    }
    
    try {
        $result = [CredentialManager]::CredDelete($Target, 1, 0)
        
        if ($result) {
            Write-TaskLog "Credential removed: $Target" -Level Success
            return $true
        }
        else {
            Write-TaskLog "Failed to remove credential (may not exist): $Target" -Level Warning
            return $false
        }
    }
    catch {
        Write-TaskLog "Error removing credential: $_" -Level Error
        return $false
    }
}

Export-ModuleMember -Function @(
    'Save-SecureCredential',
    'Get-SecureCredential',
    'Remove-SecureCredential'
)
