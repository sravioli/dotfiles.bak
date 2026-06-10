# Theme Configuration
# Configuration for oh-my-posh and other theming

function Initialize-Theme {
    <#
    .SYNOPSIS
        Initializes the PowerShell theme
    .DESCRIPTION
        Sets up oh-my-posh with the kanagawa-wave theme
    #>
    try {
        if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
            & ([ScriptBlock]::Create((oh-my-posh init pwsh --config "$HOME/.config/oh-my-posh/kanagawa-wave.omp.json" --print) -join "`n"))
        }
        else {
            Write-Warning 'oh-my-posh not found. Install it with: winget install JanDeDobbeleer.OhMyPosh'
        }
    }
    catch {
        Write-Warning "Failed to initialize oh-my-posh theme: $_"
    }
}

function Initialize-Zoxide {
    <#
    .SYNOPSIS
        Initializes zoxide for smart directory navigation
    .DESCRIPTION
        Sets up zoxide integration with PowerShell
    #>
    try {
        if (Get-Command zoxide -ErrorAction SilentlyContinue) {
            Invoke-Expression (& { (zoxide init powershell | Out-String) })
        }
        else {
            Write-Warning 'zoxide not found. Install it with: winget install ajeetdsouza.zoxide'
        }
    }
    catch {
        Write-Warning "Failed to initialize zoxide: $_"
    }
}
