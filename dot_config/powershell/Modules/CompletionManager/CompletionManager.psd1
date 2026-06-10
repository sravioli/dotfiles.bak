@{
    RootModule        = 'CompletionManager.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b3f7a2c1-8d4e-4f6a-9c1b-5e2d3a4f8b7c'
    Author            = 'Simone Fidanza'
    Description       = 'Manages static shell completion scripts for CLI tools.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Initialize-Completion'
        'Save-Completion'
        'Update-Completions'
        'Remove-Completion'
        'Test-Completion'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags = @('completion', 'shell', 'cli', 'tab-completion')
        }
    }
}
