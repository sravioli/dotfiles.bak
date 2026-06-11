# Theme Configuration
# Configuration for oh-my-posh and other theming

function Initialize-Theme {
    <#
    .SYNOPSIS
        Initializes the PowerShell theme
    .DESCRIPTION
        Sets up oh-my-posh with the kanagawa-wave theme.

        This is invoked only in interactive sessions (see the interactive guard
        in the root profile), so the oh-my-posh init subprocess is skipped for
        redirected/noninteractive startups (scripts, CI, the profiler).

        Note: the init call is intentionally run fresh on every interactive
        startup. oh-my-posh links the chosen --config to the shell through its
        own session cache, keyed by the POSH_SESSION_ID that `init` generates;
        the prompt later resolves the config from that cache (it does not honor
        $env:POSH_THEME). Caching/replaying a previous init script breaks this
        link and the prompt silently falls back to the default theme, so the
        init must not be cached.
    #>
    try {
        $ompCmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
        if (-not $ompCmd) {
            Write-Warning 'oh-my-posh not found. Install it with: winget install JanDeDobbeleer.OhMyPosh'
            return
        }

        $config = "$HOME/.config/oh-my-posh/kanagawa-wave.omp.json"
        $initScript = (& oh-my-posh init pwsh --config $config --print) -join "`n"
        if ($initScript) {
            & ([ScriptBlock]::Create($initScript))
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
