# Development Utilities
# Functions related to software development tasks

function Invoke-ExercismCsharp {
    param([string[]]$Arguments)
    try {
        Invoke-ExercismWrapper -Language csharp @Arguments
    }
    catch {
        Write-Warning "ExercismWrapper module not available: $_"
    }
}
Set-Alias -Name cs -Value Invoke-ExercismCsharp

function Invoke-NeovimWsl {
    <#
    .SYNOPSIS
        Launches Neovim in WSL
    .DESCRIPTION
        Opens Neovim editor running in Windows Subsystem for Linux
    #>
    try {
        wsl /opt/nvim-linux64/bin/nvim
    }
    catch {
        Write-Warning "Failed to launch Neovim in WSL: $_"
    }
}
Set-Alias -Name wv -Value Invoke-NeovimWsl

function Invoke-EditProfile {
    <#
    .SYNOPSIS
        Opens PowerShell profile directory in VS Code
    .DESCRIPTION
        Launches VS Code with the PowerShell profile directory open for editing
    #>
    $profilePath = if ($env:PSProfileDir) {
        $env:PSProfileDir
    }
    else {
        Split-Path $PROFILE -Parent
    }

    if (-not (Test-Path -LiteralPath $profilePath -PathType Container)) {
        Write-Warning "Profile directory not found: $profilePath"
        return
    }

    $editorCommand = @($env:VISUAL, $env:EDITOR, 'code.cmd', 'code') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { Get-Command -Name $_ -ErrorAction SilentlyContinue } |
        Select-Object -First 1

    if (-not $editorCommand) {
        Write-Warning 'No editor command found. Set $env:VISUAL or $env:EDITOR.'
        return
    }

    try {
        & $editorCommand $profilePath
    }
    catch {
        Write-Warning "Failed to open profile directory: $_"
    }
}
Set-Alias -Name ep -Value Invoke-EditProfile

function Invoke-RefreshProfile {
    <#
    .SYNOPSIS
        Reloads the PowerShell profile
    .DESCRIPTION
        Reloads the current PowerShell profile to apply any changes made to profile files
    #>
    $profileFile = if ($env:PSProfileFile) {
        $env:PSProfileFile
    }
    elseif ($env:PSProfileDir) {
        Join-Path $env:PSProfileDir 'Microsoft.PowerShell_profile.ps1'
    }
    else {
        $PROFILE
    }

    if (-not (Test-Path -LiteralPath $profileFile -PathType Leaf)) {
        Write-Error "Profile file not found: $profileFile"
        return
    }

    try {
        Write-Host 'Reloading profile...' -ForegroundColor Yellow
        $previousErrorCount = $Error.Count

        $moduleName = 'PowerShellProfile.Refresh'
        Get-Module -Name $moduleName | Remove-Module -Force -ErrorAction SilentlyContinue

        $module = New-Module -Name $moduleName -ScriptBlock {
            param([string]$ProfileFile)

            . $ProfileFile
            Export-ModuleMember -Function * -Alias *
        } -ArgumentList $profileFile

        Import-Module $module -Global -Force -DisableNameChecking

        $newErrorCount = $Error.Count - $previousErrorCount
        if ($newErrorCount -gt 0) {
            Write-Warning "Profile reloaded with $newErrorCount error(s)."
        }
        else {
            Write-Host 'Profile reloaded successfully.' -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to reload profile: $_"
    }
}
Set-Alias -Name rr -Value Invoke-RefreshProfile
