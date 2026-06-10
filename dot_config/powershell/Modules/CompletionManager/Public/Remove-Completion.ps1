function Remove-Completion {
    <#
    .SYNOPSIS
        Removes a registered completion for one or more programs.
    .DESCRIPTION
        Deletes the per-program directory (manifest + completion script) from the
        completion root. Supports -WhatIf and -Confirm for safety.
    .PARAMETER ProgramName
        One or more program names whose completions should be removed.
    .EXAMPLE
        Remove-Completion -ProgramName delta
    .EXAMPLE
        'delta', 'gh' | Remove-Completion
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ProgramName
    )

    process {
        foreach ($name in $ProgramName) {
            $root = Get-CompletionRoot
            $programDir = Join-Path $root $name

            if (-not (Test-Path $programDir)) {
                Write-Warning "Completion for '$name' not found."
                continue
            }

            if ($PSCmdlet.ShouldProcess($name, 'Remove completion')) {
                try {
                    Remove-Item -Path $programDir -Recurse -Force
                    Write-Verbose "Removed completion for '$name'."

                    [PSCustomObject]@{
                        ProgramName = $name
                        Status      = 'Removed'
                    }
                }
                catch {
                    Write-Error "Failed to remove completion for '$name': $_"
                }
            }
        }
    }
}
