function Update-Completions {
    <#
    .SYNOPSIS
        Re-generates completion scripts for registered programs.
    .DESCRIPTION
        Iterates all per-program manifests (or a specified subset), re-executes each
        stored generateCommand, and overwrites the completion file on success.
        Programs without a generateCommand (manual entries) are skipped.
        On failure the previous completion file is preserved and the manifest records
        the error for diagnostics.
    .PARAMETER ProgramName
        One or more program names to update. If omitted, all registered programs are updated.
    .EXAMPLE
        Update-Completions
    .EXAMPLE
        Update-Completions -ProgramName delta, gh
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [string[]]$ProgramName
    )

    $root = Get-CompletionRoot

    if (-not (Test-Path $root)) {
        Write-Warning "Completion root not found: $root"
        return
    }

    # Resolve target program directories
    $programDirs = if ($ProgramName) {
        foreach ($name in $ProgramName) {
            $dir = Join-Path $root $name
            if (Test-Path $dir) {
                Get-Item $dir
            }
            else {
                Write-Warning "Program '$name' not found in completions."
            }
        }
    }
    else {
        Get-ChildItem -Path $root -Directory | Sort-Object Name
    }

    $results = @()

    foreach ($dir in $programDirs) {
        $manifestPath = Join-Path $dir.FullName 'manifest.json'
        $manifest = Read-CompletionManifest -Path $manifestPath

        if (-not $manifest) {
            Write-Warning "Skipping '$($dir.Name)': no valid manifest"
            continue
        }

        if (-not $manifest.generateCommand) {
            Write-Verbose "Skipping '$($dir.Name)': no generate command (manual entry)"
            $results += [PSCustomObject]@{
                ProgramName = $dir.Name
                Status      = 'Skipped'
                Reason      = 'Manual entry (no generate command)'
            }
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($dir.Name, "Re-generate completion via: $($manifest.generateCommand)")) {
            continue
        }

        $completionFile = Join-Path $dir.FullName $manifest.completionFile
        $now = (Get-Date).ToUniversalTime().ToString('o')

        try {
            $global:LASTEXITCODE = 0
            $output = Invoke-Expression $manifest.generateCommand 2>&1

            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                throw "Generator exited with code $LASTEXITCODE"
            }

            $content = ($output | Out-String).Trim()

            if ([string]::IsNullOrWhiteSpace($content)) {
                throw 'Generator produced empty output'
            }

            # Atomic write
            $tempFile = "$completionFile.tmp"
            Set-Content -Path $tempFile -Value $content -Encoding UTF8
            Move-Item -Path $tempFile -Destination $completionFile -Force

            # Update manifest with success
            $manifestData = @{
                schemaVersion  = [int]$manifest.schemaVersion
                programName    = $manifest.programName
                shell          = $manifest.shell
                generateCommand = $manifest.generateCommand
                completionFile = $manifest.completionFile
                createdAt      = $manifest.createdAt
                updatedAt      = $now
                status         = 'ok'
                lastError      = $null
            }
            Write-CompletionManifest -Path $manifestPath -Data $manifestData

            $results += [PSCustomObject]@{
                ProgramName = $dir.Name
                Status      = 'Updated'
                Reason      = $null
            }
        }
        catch {
            # Record error in manifest but preserve the old completion file
            if (Test-Path "$completionFile.tmp") {
                Remove-Item "$completionFile.tmp" -Force -ErrorAction SilentlyContinue
            }

            $manifestData = @{
                schemaVersion  = [int]$manifest.schemaVersion
                programName    = $manifest.programName
                shell          = $manifest.shell
                generateCommand = $manifest.generateCommand
                completionFile = $manifest.completionFile
                createdAt      = $manifest.createdAt
                updatedAt      = $now
                status         = 'error'
                lastError      = $_.ToString()
            }
            Write-CompletionManifest -Path $manifestPath -Data $manifestData

            Write-Warning "Failed to update '$($dir.Name)': $_"

            $results += [PSCustomObject]@{
                ProgramName = $dir.Name
                Status      = 'Failed'
                Reason      = $_.ToString()
            }
        }
    }

    $results
}
