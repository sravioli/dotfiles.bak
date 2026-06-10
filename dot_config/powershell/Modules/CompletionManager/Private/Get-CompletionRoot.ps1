function Get-CompletionRoot {
    <#
    .SYNOPSIS
        Returns the resolved completion storage root directory.
    .DESCRIPTION
        Uses the module-scoped $CompletionRoot if set (via Initialize-Completion -RootPath),
        otherwise falls back to $env:XDG_CONFIG_HOME/completion-manager or ~/.config/completion-manager.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($script:CompletionRoot) {
        return $script:CompletionRoot
    }

    $configHome = if ($env:XDG_CONFIG_HOME) {
        $env:XDG_CONFIG_HOME
    }
    else {
        Join-Path $HOME '.config'
    }

    Join-Path $configHome 'completion-manager'
}
