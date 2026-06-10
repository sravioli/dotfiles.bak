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
$errors = @()

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
            $errors += $_
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
            $errors += $_
        }
    }
}

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
        $errors += $_
    }
}

if ($errors.Count -gt 0) {
    Write-Error -Message 'Failed to load some profile scripts:'
    $errors | ForEach-Object { Write-Error -Message " - $_" }
}
else {
    Write-Verbose -Message 'PowerShell profile loaded successfully!'
}

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
