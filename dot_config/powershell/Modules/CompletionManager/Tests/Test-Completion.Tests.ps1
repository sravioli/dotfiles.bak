BeforeAll {
    $modulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $modulePath -Force
}

Describe 'Test-Completion' {
    BeforeEach {
        $testRoot = Join-Path $TestDrive "test-$(New-Guid)"
        Initialize-Completion -RootPath $testRoot
    }

    Context 'non-existent program' {
        It 'reports Exists as false' {
            $result = Test-Completion -ProgramName ghost
            $result.Exists | Should -BeFalse
        }

        It 'flags an issue about missing directory' {
            $result = Test-Completion -ProgramName ghost
            $result.Issues | Should -Not -BeNullOrEmpty
            $result.Issues | Should -Contain ($result.Issues | Where-Object { $_ -match 'not found' })
        }
    }

    Context 'directory exists but no manifest' {
        BeforeEach {
            $dir = Join-Path $testRoot 'orphan'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }

        It 'reports Exists true but HasManifest false' {
            $result = Test-Completion -ProgramName orphan
            $result.Exists | Should -BeTrue
            $result.HasManifest | Should -BeFalse
        }
    }

    Context 'invalid manifest JSON' {
        BeforeEach {
            $dir = Join-Path $testRoot 'badjson'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            'not valid json {{{' | Set-Content (Join-Path $dir 'manifest.json')
        }

        It 'reports ManifestValid as false' {
            $result = Test-Completion -ProgramName badjson
            $result.HasManifest | Should -BeTrue
            $result.ManifestValid | Should -BeFalse
        }
    }

    Context 'manifest missing required fields' {
        BeforeEach {
            $dir = Join-Path $testRoot 'incomplete'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            @{ schemaVersion = 1 } | ConvertTo-Json | Set-Content (Join-Path $dir 'manifest.json')
        }

        It 'flags issues for each missing required field' {
            $result = Test-Completion -ProgramName incomplete
            $result.ManifestValid | Should -BeTrue
            ($result.Issues | Where-Object { $_ -match 'programName' }) | Should -Not -BeNullOrEmpty
            ($result.Issues | Where-Object { $_ -match 'shell' }) | Should -Not -BeNullOrEmpty
            ($result.Issues | Where-Object { $_ -match 'completionFile' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'manifest present but completion file missing' {
        BeforeEach {
            $dir = Join-Path $testRoot 'nofile'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            @{
                schemaVersion  = 1; programName = 'nofile'; shell = 'pwsh'
                completionFile = 'pwsh.ps1'; generateCommand = 'echo test'
            } | ConvertTo-Json | Set-Content (Join-Path $dir 'manifest.json')
            # Deliberately do NOT create pwsh.ps1
        }

        It 'reports HasCompletion as false' {
            $result = Test-Completion -ProgramName nofile
            $result.HasCompletion | Should -BeFalse
        }
    }

    Context 'fully valid entry with generateCommand' {
        BeforeEach {
            Save-Completion -ProgramName validcli `
                -GenerateCommand 'Write-Output "Register-ArgumentCompleter -Native -CommandName validcli -ScriptBlock { }"'
        }

        It 'reports all checks passing' {
            $result = Test-Completion -ProgramName validcli
            $result.Exists | Should -BeTrue
            $result.HasManifest | Should -BeTrue
            $result.HasCompletion | Should -BeTrue
            $result.ManifestValid | Should -BeTrue
            $result.ScriptValid | Should -BeTrue
            $result.Refreshable | Should -BeTrue
        }

        It 'has no issues' {
            $result = Test-Completion -ProgramName validcli
            $result.Issues.Count | Should -Be 0
        }
    }

    Context 'manual entry (no generateCommand)' {
        BeforeEach {
            '# manual' | Save-Completion -ProgramName manualcli
        }

        It 'reports Refreshable as false' {
            $result = Test-Completion -ProgramName manualcli
            $result.Refreshable | Should -BeFalse
        }

        It 'flags the missing generate command as an issue' {
            $result = Test-Completion -ProgramName manualcli
            ($result.Issues | Where-Object { $_ -match 'manual' -or $_ -match 'generate' }) |
                Should -Not -BeNullOrEmpty
        }
    }

    Context 'completion file with syntax error' {
        BeforeEach {
            $dir = Join-Path $testRoot 'syntaxerr'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            @{
                schemaVersion = 1; programName = 'syntaxerr'; shell = 'pwsh'
                completionFile = 'pwsh.ps1'; generateCommand = 'echo test'
            } | ConvertTo-Json | Set-Content (Join-Path $dir 'manifest.json')

            # Write invalid PowerShell
            'function { broken syntax {{' | Set-Content (Join-Path $dir 'pwsh.ps1')
        }

        It 'reports ScriptValid as false' {
            $result = Test-Completion -ProgramName syntaxerr
            $result.ScriptValid | Should -BeFalse
        }

        It 'includes parse errors in Issues' {
            $result = Test-Completion -ProgramName syntaxerr
            ($result.Issues | Where-Object { $_ -match 'Parse error' }) | Should -Not -BeNullOrEmpty
        }
    }
}
