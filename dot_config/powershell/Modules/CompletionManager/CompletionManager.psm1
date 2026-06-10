# CompletionManager — manages static shell completion scripts for CLI tools.
#
# Module-scoped state: completion root path (set by Initialize-Completion -RootPath).
$script:CompletionRoot = $null

# Dot-source private functions
$privatePath = Join-Path $PSScriptRoot 'Private'
if (Test-Path $privatePath) {
    foreach ($file in Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse) {
        . $file.FullName
    }
}

# Dot-source public functions
$publicPath = Join-Path $PSScriptRoot 'Public'
if (Test-Path $publicPath) {
    foreach ($file in Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse) {
        . $file.FullName
    }
}
