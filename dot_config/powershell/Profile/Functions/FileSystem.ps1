# File System Utilities
# Functions related to file and directory operations

function Invoke-EzaShort {
    param([string[]]$Arguments)
    eza.exe --oneline --color=always --icons=always --all --group-directories-first @Arguments
}

# Try to set ls alias, but don't fail if it's already set with AllScope
try {
    Set-Alias -Name ls -Value Invoke-EzaShort -Force -ErrorAction Stop
}
catch {
    Write-Verbose "Could not override 'ls' alias: $_" -Verbose:$false
}

function Invoke-EzaLong {
    param([string[]]$Arguments)
    Invoke-EzaShort --long --header --extended --time-style='long-iso' --git @Arguments
}
Set-Alias -Name ll -Value Invoke-EzaLong

function Remove-BinaryAndObjectDirectories {
    <#
    .SYNOPSIS
        Removes bin and obj directories from .NET projects
    .DESCRIPTION
        Recursively finds and removes bin and/or obj directories in the specified path
    .PARAMETER Path
        The root path to search for directories (defaults to current location)
    .PARAMETER Type
        Which directories to remove: 'bin', 'obj', or 'all' (default)
    .PARAMETER DryRun
        Shows what would be removed without actually deleting anything
    .EXAMPLE
        Remove-BinaryAndObjectDirectories -DryRun
        Shows what bin and obj directories would be removed
    .EXAMPLE
        Remove-BinaryAndObjectDirectories -Type bin -Path C:\MyProject
        Removes only bin directories in the specified project
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$Path = (Get-Location).Path,
        [ValidateSet('bin', 'obj', 'all')]
        [string]$Type = 'all',
        [switch]$DryRun
    )

    # Validate path exists
    if (-not (Test-Path $Path)) {
        Write-Error "Path '$Path' does not exist."
        return
    }

    # Configure operation based on type
    $typeConfig = @{
        bin = @{ Pattern = '^bin$'; TypeName = 'bin' }
        obj = @{ Pattern = '^obj$'; TypeName = 'obj' }
        all = @{ Pattern = '^(bin|obj)$'; TypeName = 'bin and obj' }
    }

    $config = $typeConfig[$Type]
    $action = if ($DryRun) { 'would be removed' } else { 'removing' }

    Write-Host "Scanning for $($config.TypeName) directories..." -ForegroundColor Yellow

    # Find directories with progress indication
    $directories = @()
    $processedCount = 0

    try {
        if (Test-ExecutableExists -Name 'fd') {
            Write-Host "Using 'fd' for fast search..." -ForegroundColor DarkYellow
            try {
                $fdArgs = @('--regex', $config.Pattern, '--type', 'directory', '--unrestricted', '--follow', '--path-separator', '/', $Path)
                $directories = & fd @fdArgs | ForEach-Object { Get-Item $_ }
            }
            catch {
                Write-Warning "Error running fd: $_"
                return
            }
        }
        else {
            Get-ChildItem -Path $Path -Directory -Recurse -ErrorAction Stop | ForEach-Object {
                $processedCount++
                if ($processedCount % 50 -eq 0) {
                    Write-Progress -Activity 'Scanning' -Status "Processed: $processedCount" -PercentComplete -1
                }

                if ($_.Name -match $config.Pattern) {
                    $directories += $_
                }
            }
        }
    }
    catch {
        Write-Error "Error scanning directories: $_"
        return
    }
    finally {
        Write-Progress -Activity 'Scanning directories' -Completed
    }

    if ($directories.Count -eq 0) {
        Write-Host "No $($config.TypeName) directories found." -ForegroundColor Green
        return
    }

    $verb = if ($DryRun) { 'Found' } else { 'Removing' }
    Write-Host "$verb $($directories.Count) $($config.TypeName) $(if ($directories.Count -eq 1) { 'directory' } else { 'directories' })..." -ForegroundColor Cyan

    $successCount = 0
    $failureCount = 0

    foreach ($dir in $directories) {
        if ($DryRun) {
            Write-Host "  $($dir.FullName)" -ForegroundColor Gray
            $successCount++
        }
        elseif ($PSCmdlet.ShouldProcess($dir.FullName, 'Remove Directory')) {
            try {
                Remove-Item $dir.FullName -Force -Recurse -ErrorAction Stop
                $successCount++
            }
            catch {
                Write-Warning "Failed to remove: $($dir.FullName). Error: $_"
                $failureCount++
            }
        }
    }

    # Summary
    $summary = if ($DryRun) {
        "Dry run complete. $successCount $(if ($successCount -eq 1) { 'directory' } else { 'directories' }) $action."
    }
    else {
        "Operation complete. $successCount $(if ($successCount -eq 1) { 'directory' } else { 'directories' }) removed" +
        $(if ($failureCount -gt 0) { ", $failureCount failed" } else { '' }) + '.'
    }

    Write-Host $summary -ForegroundColor Green
}
Set-Alias -Name rmbin -Value Remove-BinaryAndObjectDirectories


function Invoke-GetLocationPath {
    $path = (Get-Location).Path
    Write-Host $path
    Set-Clipboard -Value $path
}
Set-Alias -Name pwd -Value Invoke-GetLocationPath