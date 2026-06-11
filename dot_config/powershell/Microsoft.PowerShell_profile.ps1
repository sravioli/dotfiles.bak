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

$moduleRoot = Join-Path $env:PSProfileDir 'Modules'
if (Test-Path -LiteralPath $moduleRoot -PathType Container) {
    $modulePaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
    if ($modulePaths -notcontains $moduleRoot) {
        $env:PSModulePath = "$moduleRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    }

    $completionModule = Join-Path $moduleRoot 'CompletionManager'
    if (Test-Path -LiteralPath $completionModule -PathType Container) {
        try {
            Import-Module $completionModule -Force -ErrorAction Stop
        }
        catch {
            $errors.Add($_)
        }
    }
}

foreach ($dir in $(Get-ChildItem -Path "$env:PSProfileDir\Profile" -Directory)) {
    # Skip directories that contain a .skip file
    if (Test-Path -Path (Join-Path $dir.FullName '.skip')) {
        Write-Verbose -Message "Skipping profile directory (contains .skip file): $($dir.FullName)"
        continue
    }

    Write-Verbose -Message "Found profile directory: $($dir.FullName)"
    foreach ($file in $(Get-ChildItem -Path $dir.FullName -Filter *.ps1)) {
        Write-Verbose -Message "  Contains file: $($file.Name)"
        try {
            . $file.FullName
        }
        catch {
            $errors.Add($_)
        }
    }
}

if ($global:PSProfileInteractive) {
    foreach ($initializer in @('Initialize-Completion', 'Initialize-Theme', 'Initialize-Zoxide')) {
        $command = Get-Command -Name $initializer -ErrorAction SilentlyContinue
        if (-not $command) {
            Write-Verbose -Message "Skipping missing profile initializer: $initializer"
            continue
        }

        try {
            & $command
        }
        catch {
            $errors.Add($_)
        }
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

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# This is only useful in interactive shells, and is skipped when Chocolatey is
# not installed, to keep noninteractive/redirected startup cheap.
# See https://ch0.co/tab-completion for details.
if ($global:PSProfileInteractive -and $env:ChocolateyInstall) {
    $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if (Test-Path -LiteralPath $ChocolateyProfile) {
        Import-Module $ChocolateyProfile
    }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
