BeforeAll {
    $modulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $modulePath -Force
}

Describe 'Save-Completion' {
    BeforeEach {
        $testRoot = Join-Path $TestDrive "save-$(New-Guid)"
        Initialize-Completion -RootPath $testRoot
    }

    Context 'generator mode' {
        It 'creates program directory, completion file, and manifest' {
            $result = Save-Completion -ProgramName testcli `
                -GenerateCommand 'Write-Output "# completion for testcli"'

            $result.ProgramName | Should -Be 'testcli'
            $result.Status | Should -Be 'Saved'

            $dir = Join-Path $testRoot 'testcli'
            Test-Path $dir | Should -BeTrue
            Test-Path (Join-Path $dir 'pwsh.ps1') | Should -BeTrue
            Test-Path (Join-Path $dir 'manifest.json') | Should -BeTrue
        }

        It 'writes the generated content into the completion file' {
            Save-Completion -ProgramName testcli `
                -GenerateCommand 'Write-Output "Register-ArgumentCompleter -Native -CommandName testcli -ScriptBlock { }"'

            $content = Get-Content (Join-Path $testRoot 'testcli' 'pwsh.ps1') -Raw
            $content | Should -Match 'Register-ArgumentCompleter'
            $content | Should -Match 'testcli'
        }

        It 'writes a valid manifest with expected fields' {
            Save-Completion -ProgramName testcli `
                -GenerateCommand 'Write-Output "# completion"'

            $manifest = Get-Content (Join-Path $testRoot 'testcli' 'manifest.json') -Raw |
                ConvertFrom-Json

            $manifest.programName | Should -Be 'testcli'
            $manifest.shell | Should -Be 'pwsh'
            $manifest.schemaVersion | Should -Be 1
            $manifest.completionFile | Should -Be 'pwsh.ps1'
            $manifest.generateCommand | Should -Be 'Write-Output "# completion"'
            $manifest.status | Should -Be 'ok'
            $manifest.createdAt | Should -Not -BeNullOrEmpty
            $manifest.updatedAt | Should -Not -BeNullOrEmpty
        }
    }

    Context 'pipeline mode' {
        It 'saves piped content as the completion file' {
            $result = '# piped completion' | Save-Completion -ProgramName pipecli `
                -GenerateCommand 'Write-Output "unused"'

            $result.ProgramName | Should -Be 'pipecli'
            $content = Get-Content (Join-Path $testRoot 'pipecli' 'pwsh.ps1') -Raw
            $content | Should -Match 'piped completion'
        }

        It 'stores the generate command in manifest even in pipeline mode' {
            '# piped' | Save-Completion -ProgramName pipecli `
                -GenerateCommand 'some-tool --completions pwsh'

            $manifest = Get-Content (Join-Path $testRoot 'pipecli' 'manifest.json') -Raw |
                ConvertFrom-Json
            $manifest.generateCommand | Should -Be 'some-tool --completions pwsh'
        }
    }

    Context 'overwrite guard' {
        It 'errors when entry already exists and -Force not given' {
            Save-Completion -ProgramName dup -GenerateCommand 'Write-Output "v1"'
            $result = Save-Completion -ProgramName dup -GenerateCommand 'Write-Output "v2"' `
                -ErrorVariable err -ErrorAction SilentlyContinue

            $result | Should -BeNullOrEmpty
            $err | Should -Not -BeNullOrEmpty
        }

        It 'overwrites when -Force is given' {
            Save-Completion -ProgramName dup -GenerateCommand 'Write-Output "v1"'
            $result = Save-Completion -ProgramName dup `
                -GenerateCommand 'Write-Output "v2"' -Force

            $result.Status | Should -Be 'Saved'
            $content = Get-Content (Join-Path $testRoot 'dup' 'pwsh.ps1') -Raw
            $content | Should -Match 'v2'
        }

        It 'preserves createdAt on overwrite' {
            Save-Completion -ProgramName dup -GenerateCommand 'Write-Output "v1"'
            $m1 = Get-Content (Join-Path $testRoot 'dup' 'manifest.json') -Raw | ConvertFrom-Json

            Start-Sleep -Milliseconds 50
            Save-Completion -ProgramName dup -GenerateCommand 'Write-Output "v2"' -Force
            $m2 = Get-Content (Join-Path $testRoot 'dup' 'manifest.json') -Raw | ConvertFrom-Json

            $m2.createdAt | Should -Be $m1.createdAt
            $m2.updatedAt | Should -Not -Be $m1.updatedAt
        }
    }

    Context 'error handling' {
        It 'errors when generator command fails' {
            $result = Save-Completion -ProgramName failcli `
                -GenerateCommand 'throw "boom"' `
                -ErrorVariable err -ErrorAction SilentlyContinue

            $result | Should -BeNullOrEmpty
            $err | Should -Not -BeNullOrEmpty
        }

        It 'errors when generator produces empty output' {
            $result = Save-Completion -ProgramName emptycli `
                -GenerateCommand 'Write-Output ""' `
                -ErrorVariable err -ErrorAction SilentlyContinue

            $result | Should -BeNullOrEmpty
            $err | Should -Not -BeNullOrEmpty
        }
    }

    Context 'atomic writes' {
        It 'does not leave .tmp files after successful save' {
            Save-Completion -ProgramName cleancli `
                -GenerateCommand 'Write-Output "# clean"'

            $dir = Join-Path $testRoot 'cleancli'
            Get-ChildItem $dir -Filter '*.tmp' | Should -HaveCount 0
        }
    }
}
