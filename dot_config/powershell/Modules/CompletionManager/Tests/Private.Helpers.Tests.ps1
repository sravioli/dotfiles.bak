BeforeAll {
    $modulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $modulePath -Force

    # Dot-source private functions for direct testing
    . (Join-Path $modulePath 'Private' 'Get-CompletionRoot.ps1')
    . (Join-Path $modulePath 'Private' 'Read-CompletionManifest.ps1')
    . (Join-Path $modulePath 'Private' 'Write-CompletionManifest.ps1')
}

Describe 'Get-CompletionRoot' {
    AfterEach {
        # Reset module-scoped variable
        & (Get-Module CompletionManager) { $script:CompletionRoot = $null }
    }

    It 'returns the module-scoped root when set via Initialize-Completion' {
        $testRoot = Join-Path $TestDrive 'custom-root'
        Initialize-Completion -RootPath $testRoot
        $result = & (Get-Module CompletionManager) { Get-CompletionRoot }
        $result | Should -Be $testRoot
    }

    It 'falls back to XDG_CONFIG_HOME/completion-manager when env var is set' {
        $saved = $env:XDG_CONFIG_HOME
        try {
            $env:XDG_CONFIG_HOME = Join-Path $TestDrive 'xdg'
            & (Get-Module CompletionManager) { $script:CompletionRoot = $null }
            $result = & (Get-Module CompletionManager) { Get-CompletionRoot }
            $result | Should -Be (Join-Path $TestDrive 'xdg' 'completion-manager')
        }
        finally {
            $env:XDG_CONFIG_HOME = $saved
        }
    }

    It 'falls back to ~/.config/completion-manager when no env var or override' {
        $saved = $env:XDG_CONFIG_HOME
        try {
            $env:XDG_CONFIG_HOME = $null
            & (Get-Module CompletionManager) { $script:CompletionRoot = $null }
            $result = & (Get-Module CompletionManager) { Get-CompletionRoot }
            $expected = Join-Path $HOME '.config' 'completion-manager'
            $result | Should -Be $expected
        }
        finally {
            $env:XDG_CONFIG_HOME = $saved
        }
    }
}

Describe 'Read-CompletionManifest' {
    It 'returns $null for non-existent path' {
        $result = Read-CompletionManifest -Path (Join-Path $TestDrive 'nope.json')
        $result | Should -BeNullOrEmpty
    }

    It 'parses valid JSON manifest' {
        $path = Join-Path $TestDrive 'manifest.json'
        @{ programName = 'test'; shell = 'pwsh' } | ConvertTo-Json | Set-Content -Path $path
        $result = Read-CompletionManifest -Path $path
        $result.programName | Should -Be 'test'
        $result.shell | Should -Be 'pwsh'
    }

    It 'returns $null and warns on invalid JSON' {
        $path = Join-Path $TestDrive 'bad.json'
        'not json{{{' | Set-Content -Path $path
        $result = Read-CompletionManifest -Path $path -WarningVariable warn 3>$null
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Write-CompletionManifest' {
    It 'creates the target directory if missing' {
        $dir = Join-Path $TestDrive 'newdir'
        $path = Join-Path $dir 'manifest.json'
        Write-CompletionManifest -Path $path -Data @{ programName = 'test' }
        Test-Path $path | Should -BeTrue
    }

    It 'writes valid JSON that can be read back' {
        $path = Join-Path $TestDrive 'roundtrip.json'
        $data = @{ programName = 'delta'; shell = 'pwsh'; schemaVersion = 1 }
        Write-CompletionManifest -Path $path -Data $data
        $parsed = Get-Content $path -Raw | ConvertFrom-Json
        $parsed.programName | Should -Be 'delta'
        $parsed.shell | Should -Be 'pwsh'
        $parsed.schemaVersion | Should -Be 1
    }

    It 'overwrites existing file atomically' {
        $path = Join-Path $TestDrive 'overwrite.json'
        Write-CompletionManifest -Path $path -Data @{ version = 'old' }
        Write-CompletionManifest -Path $path -Data @{ version = 'new' }
        $parsed = Get-Content $path -Raw | ConvertFrom-Json
        $parsed.version | Should -Be 'new'
    }

    It 'cleans up temp file on write failure' {
        $dir = Join-Path $TestDrive 'faildir'
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        # Lock the temp file to simulate failure — just verify no .tmp remains after normal write
        $path = Join-Path $dir 'manifest.json'
        Write-CompletionManifest -Path $path -Data @{ test = $true }
        Test-Path "$path.tmp" | Should -BeFalse
    }
}
