function Initialize-Completion {
    <#
    .SYNOPSIS
        Loads all registered static completion scripts into the current session.
    .DESCRIPTION
        Scans the completion root directory for per-program folders, reads each
        manifest.json, and dot-sources the corresponding completion script.

        This is the ONLY line needed in your PowerShell profile:
            Initialize-Completion
        Or with a custom root:
            Initialize-Completion -RootPath '~/.completions'

        No completion generators are executed at startup — only pre-saved static
        scripts are loaded, keeping profile startup fast.
    .PARAMETER RootPath
        Override the default completion storage root. When specified, this path
        is remembered for the current session so other commands (Save-Completion,
        Update-Completions, etc.) use the same root.
    .EXAMPLE
        Initialize-Completion
    .EXAMPLE
        Initialize-Completion -RootPath 'D:\my-completions'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$RootPath
    )

    if ($RootPath) {
        $script:CompletionRoot = $RootPath
    }

    $root = Get-CompletionRoot

    if (-not (Test-Path $root)) {
        Write-Verbose "Completion root not found: $root — no completions to load."
        return
    }

    $programDirs = Get-ChildItem -Path $root -Directory | Sort-Object Name
    $loaded = 0
    $errors = @()

    foreach ($dir in $programDirs) {
        $manifestPath = Join-Path $dir.FullName 'manifest.json'
        $manifest = Read-CompletionManifest -Path $manifestPath

        if (-not $manifest) {
            Write-Verbose "Skipping '$($dir.Name)': no valid manifest"
            continue
        }

        if ($manifest.shell -ne 'pwsh') {
            Write-Verbose "Skipping '$($dir.Name)': shell is '$($manifest.shell)', not 'pwsh'"
            continue
        }

        $completionPath = Join-Path $dir.FullName $manifest.completionFile
        if (-not (Test-Path $completionPath)) {
            Write-Verbose "Skipping '$($dir.Name)': completion file not found"
            continue
        }

        try {
            . $completionPath
            $loaded++
        }
        catch {
            $errors += [PSCustomObject]@{
                Program = $dir.Name
                Error   = $_
            }
        }
    }

    Write-Verbose "Loaded $loaded completion(s)."

    if ($errors.Count -gt 0) {
        foreach ($err in $errors) {
            Write-Warning "Failed to load completion for '$($err.Program)': $($err.Error)"
        }
    }
}
