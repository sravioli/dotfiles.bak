BeforeAll {
    $modulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $modulePath -Force
}

Describe 'CompletionManager module' {
    It 'exports exactly 5 public functions' {
        $commands = Get-Command -Module CompletionManager
        $commands | Should -HaveCount 5
    }

    It 'exports Initialize-Completion' {
        Get-Command Initialize-Completion -Module CompletionManager | Should -Not -BeNullOrEmpty
    }

    It 'exports Save-Completion' {
        Get-Command Save-Completion -Module CompletionManager | Should -Not -BeNullOrEmpty
    }

    It 'exports Update-Completions' {
        Get-Command Update-Completions -Module CompletionManager | Should -Not -BeNullOrEmpty
    }

    It 'exports Remove-Completion' {
        Get-Command Remove-Completion -Module CompletionManager | Should -Not -BeNullOrEmpty
    }

    It 'exports Test-Completion' {
        Get-Command Test-Completion -Module CompletionManager | Should -Not -BeNullOrEmpty
    }

    It 'does not export private functions' {
        $commands = Get-Command -Module CompletionManager
        $commands.Name | Should -Not -Contain 'Get-CompletionRoot'
        $commands.Name | Should -Not -Contain 'Read-CompletionManifest'
        $commands.Name | Should -Not -Contain 'Write-CompletionManifest'
    }
}
