function Test-Completion {
    <#
    .SYNOPSIS
        Validates a registered completion entry.
    .DESCRIPTION
        Checks that the program directory, manifest, and completion script exist and
        are well-formed. Reports issues as a structured object for diagnostic use.
    .PARAMETER ProgramName
        The program name to validate.
    .EXAMPLE
        Test-Completion -ProgramName delta
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ProgramName
    )

    $root = Get-CompletionRoot
    $programDir = Join-Path $root $ProgramName
    $manifestPath = Join-Path $programDir 'manifest.json'

    $result = [ordered]@{
        ProgramName   = $ProgramName
        Exists        = $false
        HasManifest   = $false
        HasCompletion = $false
        ManifestValid = $false
        ScriptValid   = $false
        Refreshable   = $false
        Issues        = [System.Collections.Generic.List[string]]::new()
    }

    if (-not (Test-Path $programDir)) {
        $result.Issues.Add("Program directory not found: $programDir")
        return [PSCustomObject]$result
    }

    $result.Exists = $true

    # --- Manifest checks ---
    if (-not (Test-Path $manifestPath)) {
        $result.Issues.Add('manifest.json not found')
        return [PSCustomObject]$result
    }

    $result.HasManifest = $true
    $manifest = Read-CompletionManifest -Path $manifestPath

    if (-not $manifest) {
        $result.Issues.Add('manifest.json is not valid JSON')
        return [PSCustomObject]$result
    }

    $result.ManifestValid = $true

    # Required fields
    foreach ($field in @('programName', 'shell', 'completionFile')) {
        if (-not $manifest.$field) {
            $result.Issues.Add("Manifest missing required field: $field")
        }
    }

    if ($manifest.generateCommand) {
        $result.Refreshable = $true
    }
    else {
        $result.Issues.Add('No generate command — manual entry, not refreshable')
    }

    # --- Completion script checks ---
    if (-not $manifest.completionFile) {
        return [PSCustomObject]$result
    }

    $completionPath = Join-Path $programDir $manifest.completionFile

    if (-not (Test-Path $completionPath)) {
        $result.Issues.Add("Completion file not found: $($manifest.completionFile)")
        return [PSCustomObject]$result
    }

    $result.HasCompletion = $true

    # Parse the script for syntax errors
    try {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $completionPath,
            [ref]$tokens,
            [ref]$parseErrors
        )

        if ($parseErrors.Count -eq 0) {
            $result.ScriptValid = $true
        }
        else {
            foreach ($err in $parseErrors) {
                $result.Issues.Add("Parse error: $($err.Message)")
            }
        }
    }
    catch {
        $result.Issues.Add("Failed to parse script: $_")
    }

    [PSCustomObject]$result
}
