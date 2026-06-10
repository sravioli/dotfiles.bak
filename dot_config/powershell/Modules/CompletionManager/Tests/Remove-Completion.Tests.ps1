BeforeAll {
    $modulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $modulePath -Force
}

Describe 'Remove-Completion' {
    BeforeEach {
        $testRoot = Join-Path $TestDrive "remove-$(New-Guid)"
        Initialize-Completion -RootPath $testRoot
    }

    Context 'removing an existing completion' {
        BeforeEach {
            Save-Completion -ProgramName delme `
                -GenerateCommand 'Write-Output "# delete me"'
        }

        It 'deletes the program directory' {
            Remove-Completion -ProgramName delme -Confirm:$false
            Test-Path (Join-Path $testRoot 'delme') | Should -BeFalse
        }

        It 'returns Removed status' {
            $result = Remove-Completion -ProgramName delme -Confirm:$false
            $result.ProgramName | Should -Be 'delme'
            $result.Status | Should -Be 'Removed'
        }
    }

    Context 'removing multiple programs' {
        BeforeEach {
            Save-Completion -ProgramName alpha -GenerateCommand 'Write-Output "a"'
            Save-Completion -ProgramName bravo -GenerateCommand 'Write-Output "b"'
        }

        It 'removes all specified programs' {
            $results = Remove-Completion -ProgramName alpha, bravo -Confirm:$false
            $results | Should -HaveCount 2
            Test-Path (Join-Path $testRoot 'alpha') | Should -BeFalse
            Test-Path (Join-Path $testRoot 'bravo') | Should -BeFalse
        }
    }

    Context 'pipeline input' {
        BeforeEach {
            Save-Completion -ProgramName piped -GenerateCommand 'Write-Output "p"'
        }

        It 'accepts program names from pipeline' {
            $result = 'piped' | Remove-Completion -Confirm:$false
            $result.ProgramName | Should -Be 'piped'
            Test-Path (Join-Path $testRoot 'piped') | Should -BeFalse
        }
    }

    Context 'non-existent program' {
        It 'warns when program is not found' {
            Remove-Completion -ProgramName ghost -Confirm:$false `
                -WarningVariable warnings 3>$null
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'does not throw' {
            { Remove-Completion -ProgramName ghost -Confirm:$false `
                -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'WhatIf support' {
        BeforeEach {
            Save-Completion -ProgramName safe `
                -GenerateCommand 'Write-Output "# safe"'
        }

        It 'does not delete when -WhatIf is used' {
            Remove-Completion -ProgramName safe -WhatIf
            Test-Path (Join-Path $testRoot 'safe') | Should -BeTrue
        }
    }
}
