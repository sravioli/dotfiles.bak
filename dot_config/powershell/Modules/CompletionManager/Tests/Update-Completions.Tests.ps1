BeforeAll {
    $modulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $modulePath -Force
}

Describe 'Update-Completions' {
    BeforeEach {
        $testRoot = Join-Path $TestDrive "update-$(New-Guid)"
        Initialize-Completion -RootPath $testRoot
    }

    Context 'single program update' {
        It 'regenerates the completion file and returns Updated status' {
            Save-Completion -ProgramName updcli `
                -GenerateCommand 'Write-Output "# v1"'

            # Change the generator to produce different output
            $manifestPath = Join-Path $testRoot 'updcli' 'manifest.json'
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.generateCommand = 'Write-Output "# v2"'
            $manifest | ConvertTo-Json | Set-Content $manifestPath

            $result = Update-Completions -ProgramName updcli -Confirm:$false
            $result.Status | Should -Be 'Updated'

            $content = Get-Content (Join-Path $testRoot 'updcli' 'pwsh.ps1') -Raw
            $content | Should -Match 'v2'
        }

        It 'updates the manifest timestamps' {
            Save-Completion -ProgramName updcli -GenerateCommand 'Write-Output "# test"'
            $m1 = Get-Content (Join-Path $testRoot 'updcli' 'manifest.json') -Raw | ConvertFrom-Json

            Start-Sleep -Milliseconds 50
            Update-Completions -ProgramName updcli -Confirm:$false

            $m2 = Get-Content (Join-Path $testRoot 'updcli' 'manifest.json') -Raw | ConvertFrom-Json
            $m2.updatedAt | Should -Not -Be $m1.updatedAt
            $m2.status | Should -Be 'ok'
        }
    }

    Context 'update all' {
        BeforeEach {
            Save-Completion -ProgramName alpha -GenerateCommand 'Write-Output "# alpha"'
            Save-Completion -ProgramName bravo -GenerateCommand 'Write-Output "# bravo"'
        }

        It 'updates every registered program' {
            $results = Update-Completions -Confirm:$false
            $results | Should -HaveCount 2
            $results | ForEach-Object { $_.Status | Should -Be 'Updated' }
        }
    }

    Context 'manual entries (no generateCommand)' {
        BeforeEach {
            '# manual content' | Save-Completion -ProgramName manual
        }

        It 'skips manual entries with Skipped status' {
            $results = Update-Completions -Confirm:$false
            $results | Should -HaveCount 1
            $results[0].Status | Should -Be 'Skipped'
            $results[0].Reason | Should -Match 'manual'
        }
    }

    Context 'failure handling' {
        BeforeEach {
            Save-Completion -ProgramName failcli `
                -GenerateCommand 'Write-Output "# good"'

            # Sabotage the generator command
            $manifestPath = Join-Path $testRoot 'failcli' 'manifest.json'
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.generateCommand = 'throw "kaboom"'
            $manifest | ConvertTo-Json | Set-Content $manifestPath
        }

        It 'returns Failed status on generator error' {
            $results = Update-Completions -ProgramName failcli -Confirm:$false `
                -WarningVariable warnings 3>$null
            $results[0].Status | Should -Be 'Failed'
        }

        It 'preserves the old completion file on failure' {
            $originalContent = Get-Content (Join-Path $testRoot 'failcli' 'pwsh.ps1') -Raw
            Update-Completions -ProgramName failcli -Confirm:$false -WarningVariable w 3>$null
            $preserved = Get-Content (Join-Path $testRoot 'failcli' 'pwsh.ps1') -Raw
            $preserved | Should -Be $originalContent
        }

        It 'records the error in the manifest' {
            Update-Completions -ProgramName failcli -Confirm:$false -WarningVariable w 3>$null
            $manifest = Get-Content (Join-Path $testRoot 'failcli' 'manifest.json') -Raw |
                ConvertFrom-Json
            $manifest.status | Should -Be 'error'
            $manifest.lastError | Should -Not -BeNullOrEmpty
        }
    }

    Context 'non-existent program' {
        It 'warns when program is not registered' {
            Update-Completions -ProgramName ghost -Confirm:$false `
                -WarningVariable warnings 3>$null
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'empty root' {
        It 'warns when root does not exist' {
            & (Get-Module CompletionManager) { $script:CompletionRoot = $null }
            $emptyRoot = Join-Path $TestDrive 'empty-root'
            Initialize-Completion -RootPath $emptyRoot

            Update-Completions -Confirm:$false -WarningVariable warnings 3>$null
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
