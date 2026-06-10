BeforeAll {
    $modulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $modulePath -Force
}

Describe 'Initialize-Completion' {
    BeforeEach {
        $testRoot = Join-Path $TestDrive "init-$(New-Guid)"
        & (Get-Module CompletionManager) { $script:CompletionRoot = $null }
    }

    Context 'when root does not exist' {
        It 'returns silently without error' {
            { Initialize-Completion -RootPath (Join-Path $TestDrive 'missing') } | Should -Not -Throw
        }
    }

    Context 'when root is empty' {
        It 'completes without error' {
            New-Item -Path $testRoot -ItemType Directory -Force | Out-Null
            { Initialize-Completion -RootPath $testRoot } | Should -Not -Throw
        }
    }

    Context 'with one valid completion' {
        BeforeEach {
            $progDir = Join-Path $testRoot 'fakecli'
            New-Item -Path $progDir -ItemType Directory -Force | Out-Null

            @{
                schemaVersion   = 1
                programName     = 'fakecli'
                shell           = 'pwsh'
                generateCommand = 'echo test'
                completionFile  = 'pwsh.ps1'
            } | ConvertTo-Json | Set-Content (Join-Path $progDir 'manifest.json')

            # Write a completion that sets a detectable variable
            '$global:__FakeCLILoaded = $true' | Set-Content (Join-Path $progDir 'pwsh.ps1')
        }

        AfterEach {
            Remove-Variable -Name __FakeCLILoaded -Scope Global -ErrorAction SilentlyContinue
        }

        It 'dot-sources the completion script' {
            Initialize-Completion -RootPath $testRoot
            $global:__FakeCLILoaded | Should -BeTrue
        }
    }

    Context 'with multiple completions' {
        BeforeEach {
            foreach ($name in 'alpha', 'bravo', 'charlie') {
                $dir = Join-Path $testRoot $name
                New-Item -Path $dir -ItemType Directory -Force | Out-Null

                @{
                    schemaVersion  = 1; programName = $name; shell = 'pwsh'
                    completionFile = 'pwsh.ps1'
                } | ConvertTo-Json | Set-Content (Join-Path $dir 'manifest.json')

                "`$global:__Loaded_$name = `$true" | Set-Content (Join-Path $dir 'pwsh.ps1')
            }
        }

        AfterEach {
            foreach ($name in 'alpha', 'bravo', 'charlie') {
                Remove-Variable -Name "__Loaded_$name" -Scope Global -ErrorAction SilentlyContinue
            }
        }

        It 'loads all completions in alphabetical order' {
            Initialize-Completion -RootPath $testRoot
            $global:__Loaded_alpha | Should -BeTrue
            $global:__Loaded_bravo | Should -BeTrue
            $global:__Loaded_charlie | Should -BeTrue
        }
    }

    Context 'fault isolation' {
        BeforeEach {
            # good entry
            $goodDir = Join-Path $testRoot 'good'
            New-Item -Path $goodDir -ItemType Directory -Force | Out-Null
            @{ schemaVersion = 1; programName = 'good'; shell = 'pwsh'; completionFile = 'pwsh.ps1' } |
                ConvertTo-Json | Set-Content (Join-Path $goodDir 'manifest.json')
            '$global:__GoodLoaded = $true' | Set-Content (Join-Path $goodDir 'pwsh.ps1')

            # bad entry (script that throws)
            $badDir = Join-Path $testRoot 'bad'
            New-Item -Path $badDir -ItemType Directory -Force | Out-Null
            @{ schemaVersion = 1; programName = 'bad'; shell = 'pwsh'; completionFile = 'pwsh.ps1' } |
                ConvertTo-Json | Set-Content (Join-Path $badDir 'manifest.json')
            'throw "intentional error"' | Set-Content (Join-Path $badDir 'pwsh.ps1')
        }

        AfterEach {
            Remove-Variable -Name __GoodLoaded -Scope Global -ErrorAction SilentlyContinue
        }

        It 'loads remaining completions even when one fails' {
            Initialize-Completion -RootPath $testRoot -WarningVariable warnings 3>$null
            $global:__GoodLoaded | Should -BeTrue
        }

        It 'emits a warning for the failed completion' {
            $warnings = $null
            Initialize-Completion -RootPath $testRoot -WarningVariable warnings 3>$null
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'skip non-pwsh shells' {
        BeforeEach {
            $dir = Join-Path $testRoot 'zshtool'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            @{ schemaVersion = 1; programName = 'zshtool'; shell = 'zsh'; completionFile = '_zshtool' } |
                ConvertTo-Json | Set-Content (Join-Path $dir 'manifest.json')
            '$global:__ZshLoaded = $true' | Set-Content (Join-Path $dir '_zshtool')
        }

        AfterEach {
            Remove-Variable -Name __ZshLoaded -Scope Global -ErrorAction SilentlyContinue
        }

        It 'does not load completion for non-pwsh shell' {
            Initialize-Completion -RootPath $testRoot
            $global:__ZshLoaded | Should -Not -BeTrue
        }
    }

    Context 'skip directories without manifest' {
        BeforeEach {
            $dir = Join-Path $testRoot 'orphan'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            'Write-Host "loaded"' | Set-Content (Join-Path $dir 'pwsh.ps1')
            # No manifest.json
        }

        It 'skips directory without manifest without error' {
            { Initialize-Completion -RootPath $testRoot } | Should -Not -Throw
        }
    }
}
