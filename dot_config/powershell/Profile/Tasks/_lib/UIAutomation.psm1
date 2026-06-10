<#
.SYNOPSIS
    UI automation helpers for PowerShell tasks.

.DESCRIPTION
    Provides UI automation functions including SendKeys and Outlook OTP extraction.

.NOTES
    Author: Task Management System
    Version: 2.0.0
    Last Updated: 2025-11-11
#>

function Send-Keys {
    <#
    .SYNOPSIS
        Sends keystrokes to the active window.
    
    .PARAMETER Keys
        Keys to send using SendKeys syntax.
        See: https://docs.microsoft.com/en-us/dotnet/api/system.windows.forms.sendkeys
    
    .EXAMPLE
        Send-Keys "{ENTER}"
    
    .EXAMPLE
        Send-Keys "Hello World"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Keys
    )
    
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [System.Windows.Forms.SendKeys]::SendWait($Keys)
        Write-Verbose "Sent keys: $Keys"
    }
    catch {
        Write-Warning "Failed to send keys: $_"
    }
}

function Get-OutlookOTP {
    <#
    .SYNOPSIS
        Extracts OTP from latest Outlook email matching "Token code: XXXXXX" pattern.
    
    .DESCRIPTION
        Searches Outlook inbox for recent emails with subject containing OTP code.
        Extracts the 6-digit code from subject line and marks email as read.
        Properly releases COM objects and disconnects from MAPI.
    
    .PARAMETER EmailSubject
        Subject pattern to filter emails. Supports wildcards. Default: '*Token code*'
    
    .PARAMETER OTPPattern
        Regex pattern to extract OTP. Default matches 6-digit codes in "Token code: XXXXXX" format.
    
    .PARAMETER MaxRetries
        Number of times to retry finding the email. Default is 5.
    
    .PARAMETER RetryDelay
        Seconds to wait between retries. Default is 2.
    
    .PARAMETER MaxEmailAge
        Maximum age of email in minutes to consider. Default is 1.
    
    .PARAMETER MaxEmailsToCheck
        Maximum number of recent emails to check. Default is 20.
    
    .EXAMPLE
        $otp = Get-OutlookOTP
        if ($otp) { Write-Host "OTP: $otp" }
    
    .EXAMPLE
        $otp = Get-OutlookOTP -MaxRetries 10 -RetryDelay 3 -MaxEmailAge 2
    
    .OUTPUTS
        String containing the OTP code, or $null if not found
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$EmailSubject = '*Token code*',
        
        [Parameter()]
        [string]$OTPPattern = 'Token code:\s*(\d{6})',
        
        [Parameter()]
        [int]$MaxRetries = 5,
        
        [Parameter()]
        [int]$RetryDelay = 2,
        
        [Parameter()]
        [int]$MaxEmailAge = 1,
        
        [Parameter()]
        [int]$MaxEmailsToCheck = 20
    )
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $outlook = $null
        $namespace = $null
        $inbox = $null
        $items = $null
        
        try {
            Write-Verbose "Searching for OTP in Outlook (attempt $attempt/$MaxRetries)..."
            
            # Connect to Outlook
            $outlook = New-Object -ComObject Outlook.Application
            $namespace = $outlook.GetNamespace('MAPI')
            $inbox = $namespace.GetDefaultFolder(6)  # olFolderInbox
            $items = $inbox.Items
            $items.Sort('[ReceivedTime]', $true)  # Sort newest first
            
            $otpFound = $null
            $emailsChecked = 0
            
            foreach ($item in $items) {
                $emailsChecked++
                
                if ($emailsChecked -gt $MaxEmailsToCheck) {
                    Write-Verbose "Checked $MaxEmailsToCheck most recent emails, stopping search"
                    break
                }
                
                # Check if email subject matches OTP pattern
                if ($item.Subject -match $OTPPattern) {
                    $emailAge = (Get-Date) - $item.ReceivedTime
                    $ageMinutes = [math]::Round($emailAge.TotalMinutes, 1)
                    
                    Write-Verbose "Found matching email: '$($item.Subject)' (Age: $ageMinutes min)"
                    
                    if ($emailAge.TotalMinutes -le $MaxEmailAge) {
                        # Extract OTP from regex match
                        $otpFound = $matches[1]
                        Write-Verbose "OTP extracted: $otpFound"
                        
                        # Mark email as read
                        try {
                            if ($item.UnRead) {
                                $item.UnRead = $false
                                $item.Save()
                                Write-Verbose 'Marked email as read'
                            }
                        }
                        catch {
                            Write-Verbose "Could not mark email as read: $_"
                        }
                        
                        break
                    }
                    else {
                        Write-Verbose "Email too old ($ageMinutes minutes), skipping"
                    }
                }
            }
            
            if ($otpFound) {
                return $otpFound
            }
            
            Write-Verbose 'No matching OTP email found in inbox'
        }
        catch {
            Write-Verbose "Error accessing Outlook: $_"
        }
        finally {
            # Clean up COM objects and disconnect from MAPI
            Write-Verbose 'Releasing Outlook COM objects...'
            
            if ($items) {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($items) | Out-Null
                $items = $null
            }
            
            if ($inbox) {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($inbox) | Out-Null
                $inbox = $null
            }
            
            if ($namespace) {
                try {
                    $namespace.Logoff()
                    Write-Verbose 'Logged off from MAPI'
                }
                catch {
                    Write-Verbose "MAPI logoff error: $_"
                }
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($namespace) | Out-Null
                $namespace = $null
            }
            
            if ($outlook) {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($outlook) | Out-Null
                $outlook = $null
            }
            
            # Force garbage collection
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            
            Write-Verbose 'Outlook cleanup complete'
        }
        
        # Wait before retry
        if ($attempt -lt $MaxRetries) {
            Write-Verbose "Waiting $RetryDelay seconds before retry..."
            Start-Sleep -Seconds $RetryDelay
        }
    }
    
    Write-Verbose "Failed to find OTP after $MaxRetries attempts"
    return $null
}

Export-ModuleMember -Function @(
    'Send-Keys',
    'Get-OutlookOTP'
)
