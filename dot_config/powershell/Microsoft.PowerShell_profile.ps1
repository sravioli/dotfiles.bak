$env:PSProfileDir = if ($MyInvocation.MyCommand.Path) {
    Split-Path $MyInvocation.MyCommand.Path -Parent -Resolve
}
else {
    Split-Path $PROFILE -Parent
}
$env:PSProfileFile = if ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
}
else {
    $PROFILE
}

Write-Verbose -Message 'Loading PowerShell profile...'

$ErrorActionPreference = 'Continue'
$errors = [System.Collections.Generic.List[object]]::new()

# Detect a real interactive console. Prompt theming (oh-my-posh), zoxide,
# predictive PSReadLine and completion registration are only useful here, and
# some of them error out or waste time when output is redirected (pipes, CI,
# the profiler). Set PSPROFILE_FORCE_INTERACTIVE=1 to force the interactive
# path, e.g. when benchmarking/profiling the full startup cost.
$global:PSProfileInteractive = if ($env:PSPROFILE_FORCE_INTERACTIVE) {
    $env:PSPROFILE_FORCE_INTERACTIVE -notin @('0', 'false', 'False', '')
}
else {
    -not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected
}

$moduleRoot = [System.IO.Path]::Combine($env:PSProfileDir, 'Modules')
if ([System.IO.Directory]::Exists($moduleRoot)) {
    # Register the profile-local module directory so modules (e.g.
    # CompletionManager) resolve by name. The CompletionManager import itself is
    # deferred to first idle in interactive sessions (see the deferred loader
    # near the end of this file), which keeps both interactive and
    # noninteractive startup cheap.
    $modulePaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
    if ($modulePaths -notcontains $moduleRoot) {
        $env:PSModulePath = "$moduleRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    }
}

# Dot-source every *.ps1 under each direct Profile subdirectory, skipping any
# directory that contains a .skip marker. Uses System.IO directly instead of
# Get-ChildItem/Test-Path/Join-Path (~8 ms faster per load, measured) and sorts
# the results to preserve the previous alphabetical load order.
$profileConfigRoot = [System.IO.Path]::Combine($env:PSProfileDir, 'Profile')
if ([System.IO.Directory]::Exists($profileConfigRoot)) {
    $profileDirs = [System.IO.Directory]::GetDirectories($profileConfigRoot)
    [System.Array]::Sort($profileDirs)
    foreach ($dir in $profileDirs) {
        # Skip directories that contain a .skip file
        if ([System.IO.File]::Exists([System.IO.Path]::Combine($dir, '.skip'))) {
            Write-Verbose -Message "Skipping profile directory (contains .skip file): $dir"
            continue
        }

        Write-Verbose -Message "Found profile directory: $dir"
        $profileFiles = [System.IO.Directory]::GetFiles($dir, '*.ps1')
        [System.Array]::Sort($profileFiles)
        foreach ($file in $profileFiles) {
            Write-Verbose -Message "  Contains file: $([System.IO.Path]::GetFileName($file))"
            try {
                . $file
            }
            catch {
                $errors.Add($_)
            }
        }
    }
}

if ($global:PSProfileInteractive) {
    # Run the prompt theme (oh-my-posh) synchronously so the themed prompt is
    # present on the very first render (no plain-prompt flash). zoxide,
    # completions and Chocolatey tab-completion are loaded asynchronously on
    # first idle (see the deferred loader near the end of this file).
    $themeCommand = Get-Command -Name Initialize-Theme -ErrorAction SilentlyContinue
    if ($themeCommand) {
        try {
            & $themeCommand
        }
        catch {
            $errors.Add($_)
        }
    }
    else {
        Write-Verbose -Message 'Skipping missing profile initializer: Initialize-Theme'
    }
}
else {
    Write-Verbose -Message 'Noninteractive session: skipping prompt, zoxide and completion initializers.'
}

if ($errors.Count -gt 0) {
    $summary = ($errors | ForEach-Object { $_.ToString() }) -join '; '
    Write-Warning -Message "PowerShell profile loaded with $($errors.Count) error(s): $summary"
}
else {
    Write-Verbose -Message 'PowerShell profile loaded successfully!'
}

# Defer the remaining interactive-only setup — completions, zoxide and
# Chocolatey tab-completion — to the first idle moments after the prompt is
# shown. This keeps the themed prompt fast while the rest loads in the
# background and binds into the global session (functions, aliases and argument
# completers). See https://matt.kotsenas.com/posts/pwsh-profiling-async-startup
if ($global:PSProfileInteractive) {
    $global:PSProfileDeferredErrors = [System.Collections.Generic.List[object]]::new()
    $global:PSProfileDeferredQueue = [System.Collections.Generic.Queue[scriptblock]]::new()

    # CompletionManager: import from the profile-local module dir and load the
    # pre-saved static completion scripts.
    $global:PSProfileDeferredQueue.Enqueue({
            $completionModule = [System.IO.Path]::Combine($env:PSProfileDir, 'Modules', 'CompletionManager')
            if ([System.IO.Directory]::Exists($completionModule)) {
                Import-Module $completionModule -Force -Global -ErrorAction Stop
                Initialize-Completion
            }
        })

    # zoxide smart directory navigation (its init binds global: by itself).
    $global:PSProfileDeferredQueue.Enqueue({
            if (Get-Command Initialize-Zoxide -ErrorAction SilentlyContinue) {
                Initialize-Zoxide
            }
        })

    # Chocolatey tab-completion, only when Chocolatey is installed.
    # See https://ch0.co/tab-completion for details.
    $global:PSProfileDeferredQueue.Enqueue({
            if ($env:ChocolateyInstall) {
                $chocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
                if ([System.IO.File]::Exists($chocolateyProfile)) {
                    Import-Module $chocolateyProfile -Global
                }
            }
        })

    # Process one chunk per idle tick, then report any errors once, clean up the
    # shared state and unsubscribe.
    $null = Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PSEngineEvent]::OnIdle) -SupportEvent -Action {
        if (-not $global:PSProfileDeferredQueue) { return }

        if ($global:PSProfileDeferredQueue.Count -gt 0) {
            $chunk = $global:PSProfileDeferredQueue.Dequeue()
            try { & $chunk }
            catch { $global:PSProfileDeferredErrors.Add($_) }
        }

        if ($global:PSProfileDeferredQueue.Count -eq 0) {
            $deferredErrors = $global:PSProfileDeferredErrors
            Remove-Variable -Name 'PSProfileDeferredQueue', 'PSProfileDeferredErrors' -Scope Global -ErrorAction SilentlyContinue
            Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -Force
            if ($deferredErrors.Count -gt 0) {
                $summary = ($deferredErrors | ForEach-Object { $_.ToString() }) -join '; '
                Write-Warning "Deferred profile init completed with $($deferredErrors.Count) error(s): $summary"
            }
        }
    }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
