function Save-Completion {
    <#
    .SYNOPSIS
        Saves a shell completion script for a CLI program.
    .DESCRIPTION
        Runs the specified generator command (or accepts pipeline input), persists the
        completion script to the per-program directory, and writes a manifest with
        metadata needed for future updates.

        Generator mode (primary):
            Save-Completion -ProgramName delta -GenerateCommand 'delta --generate-completion powershell'

        Pipeline mode (manual / testing):
            'script content' | Save-Completion -ProgramName delta

        If both -GenerateCommand and pipeline input are given, pipeline input is used
        and the generate command is stored for future refreshes via Update-Completions.
    .PARAMETER ProgramName
        Name of the CLI program (used as folder name and registry key).
    .PARAMETER GenerateCommand
        Shell command that outputs the completion script to stdout.
    .PARAMETER Force
        Overwrite an existing completion entry without prompting.
    .EXAMPLE
        Save-Completion -ProgramName delta -GenerateCommand 'delta --generate-completion powershell'
    .EXAMPLE
        'custom script' | Save-Completion -ProgramName mytool -GenerateCommand 'mytool completions pwsh'
    #>
    [CmdletBinding(DefaultParameterSetName = 'Generate', SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ProgramName,

        [Parameter(Mandatory, ParameterSetName = 'Generate', Position = 1)]
        [Parameter(ParameterSetName = 'Pipeline')]
        [ValidateNotNullOrEmpty()]
        [string]$GenerateCommand,

        [Parameter(Mandatory, ParameterSetName = 'Pipeline', ValueFromPipeline)]
        [string]$InputObject,

        [switch]$Force
    )

    begin {
        $pipelineInput = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($InputObject) {
            $pipelineInput.Add($InputObject)
        }
    }

    end {
        $root = Get-CompletionRoot
        $programDir = Join-Path $root $ProgramName
        $completionFile = Join-Path $programDir 'pwsh.ps1'
        $manifestPath = Join-Path $programDir 'manifest.json'

        # Guard against accidental overwrite
        if ((Test-Path $manifestPath) -and -not $Force) {
            Write-Error "Completion for '$ProgramName' already exists. Use -Force to overwrite."
            return
        }

        # Resolve completion script content
        $content = $null

        if ($pipelineInput.Count -gt 0) {
            # Pipeline mode — use piped content directly
            $content = $pipelineInput -join "`n"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Generate') {
            # Generator mode — run command
            if (-not $PSCmdlet.ShouldProcess($ProgramName, "Generate completion via: $GenerateCommand")) {
                return
            }

            try {
                $global:LASTEXITCODE = 0
                $output = Invoke-Expression $GenerateCommand 2>&1

                if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                    Write-Error "Generator command failed with exit code $LASTEXITCODE for '$ProgramName'."
                    return
                }

                $content = ($output | Out-String).Trim()
            }
            catch {
                Write-Error "Failed to execute generator command for '$ProgramName': $_"
                return
            }
        }
        else {
            Write-Error "No input received. Provide either -GenerateCommand or pipeline input."
            return
        }

        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Error "Generated completion script is empty for '$ProgramName'."
            return
        }

        # Ensure program directory exists
        if (-not (Test-Path $programDir)) {
            New-Item -Path $programDir -ItemType Directory -Force | Out-Null
        }

        # Atomic write: completion script
        $tempFile = "$completionFile.tmp"
        try {
            Set-Content -Path $tempFile -Value $content -Encoding UTF8
            Move-Item -Path $tempFile -Destination $completionFile -Force
        }
        catch {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
            Write-Error "Failed to write completion file for '$ProgramName': $_"
            return
        }

        # Build manifest
        $now = (Get-Date).ToUniversalTime().ToString('o')
        $existing = Read-CompletionManifest -Path $manifestPath

        $manifestData = @{
            schemaVersion  = 1
            programName    = $ProgramName
            shell          = 'pwsh'
            generateCommand = if ($GenerateCommand) { $GenerateCommand } else { $null }
            completionFile = 'pwsh.ps1'
            createdAt      = if ($existing) { $existing.createdAt } else { $now }
            updatedAt      = $now
            status         = 'ok'
            lastError      = $null
        }

        try {
            Write-CompletionManifest -Path $manifestPath -Data $manifestData
        }
        catch {
            Write-Error "Failed to write manifest for '$ProgramName': $_"
            return
        }

        Write-Verbose "Saved completion for '$ProgramName' at $completionFile"

        [PSCustomObject]@{
            ProgramName     = $ProgramName
            CompletionFile  = $completionFile
            GenerateCommand = $GenerateCommand
            Status          = 'Saved'
        }
    }
}
