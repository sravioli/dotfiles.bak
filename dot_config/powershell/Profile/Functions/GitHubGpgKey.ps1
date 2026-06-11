# GitHub GPG signing key helper.
# Defines New-GitHubGpgKey. Helper functions are nested so dot-sourcing this
# profile file only exposes the public command and keeps helpers out of global scope.

function New-GitHubGpgKey {
    <#
    .SYNOPSIS
    Creates a new GPG key for GitHub commit and tag signing.

    .DESCRIPTION
    Creates a new OpenPGP key in your local GPG keyring, exports the public key in
    ASCII armor format, suggests a GitHub key title, and prints the GitHub account
    settings URL where you can add the public key. The private key is not exported
    or written to this workspace.

    Use an email address that is verified on your GitHub account. If you use GitHub
    email privacy, pass your GitHub no-reply email address instead.

    GitHub docs:
    - https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key
    - https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account
    - https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key

    .EXAMPLE
    New-GitHubGpgKey -Name "Mona Lisa" -Email "mona@example.com"

    .EXAMPLE
    New-GitHubGpgKey -Name "Mona Lisa" -Email "mona@example.com" -ConfigureGit -SignCommitsByDefault -SignTagsByDefault

    .EXAMPLE
    New-GitHubGpgKey -Name "Mona Lisa" -Email "mona@example.com" -ConfigureGit -EnableCommitSigning -EnableTagSigning

    .EXAMPLE
    New-GitHubGpgKey -Name "Mona Lisa" -Email "mona@example.com" -ConfigureGit -EnableSigning

    .EXAMPLE
    New-GitHubGpgKey -Name "Mona Lisa" -Email "mona@example.com" -ReplaceExisting -ConfigureGit
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
        [string] $Email,

        [ValidateSet('Ed25519', 'RSA4096')]
        [string] $Algorithm = 'Ed25519',

        # Use 0 for no expiration. Examples: 1y, 6m, 90d.
        [ValidateNotNullOrEmpty()]
        [string] $Expire = '0',

        # Configure global Git signing key after creating the GPG key.
        [switch] $ConfigureGit,

        # Requires -ConfigureGit.
        [Alias('EnableCommitSigning')]
        [switch] $SignCommitsByDefault,

        # Requires -ConfigureGit.
        [Alias('EnableTagSigning')]
        [switch] $SignTagsByDefault,

        # Requires -ConfigureGit. Enables both commit and tag signing.
        [switch] $EnableSigning,

        # Deletes matching local GPG secret/public keys before creating the new key.
        # This does not remove already-added GPG keys from your GitHub account.
        [switch] $ReplaceExisting,

        [switch] $NoClipboard,

        [ValidateNotNullOrEmpty()]
        [string] $OutputDirectory = (Get-Location).Path,

        [ValidateNotNullOrEmpty()]
        [string] $GpgCommand = 'gpg',

        [ValidateNotNullOrEmpty()]
        [string] $GitCommand = 'git'
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    function Resolve-RequiredCommand {
        param(
            [Parameter(Mandatory = $true)]
            [string] $CommandName,

            [Parameter(Mandatory = $true)]
            [string] $InstallMessage
        )

        $command = Get-Command $CommandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $command) {
            throw "Could not find '$CommandName' on PATH. $InstallMessage"
        }

        if ($command.Path) {
            return $command.Path
        }

        return $command.Source
    }

    function ConvertTo-WindowsArgument {
        param(
            [AllowEmptyString()]
            [Parameter(Mandatory = $true)]
            [string] $Argument
        )

        if ($Argument.Length -eq 0) {
            return '""'
        }

        if ($Argument -notmatch '[\s"]') {
            return $Argument
        }

        $result = New-Object System.Text.StringBuilder
        [void] $result.Append('"')
        $backslashes = 0

        foreach ($character in $Argument.ToCharArray()) {
            if ($character -eq '\') {
                $backslashes += 1
                continue
            }

            if ($character -eq '"') {
                [void] $result.Append('\' * (($backslashes * 2) + 1))
                [void] $result.Append('"')
                $backslashes = 0
                continue
            }

            if ($backslashes -gt 0) {
                [void] $result.Append('\' * $backslashes)
                $backslashes = 0
            }

            [void] $result.Append($character)
        }

        if ($backslashes -gt 0) {
            [void] $result.Append('\' * ($backslashes * 2))
        }

        [void] $result.Append('"')
        return $result.ToString()
    }

    function Format-DisplayCommand {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Command,

            [Parameter(Mandatory = $true)]
            [string[]] $Arguments
        )

        return ((@($Command) + ($Arguments | ForEach-Object { ConvertTo-WindowsArgument -Argument $_ })) -join ' ')
    }

    function Invoke-NativeCapture {
        param(
            [Parameter(Mandatory = $true)]
            [string] $FilePath,

            [Parameter(Mandatory = $true)]
            [string[]] $Arguments
        )

        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $FilePath
        $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-WindowsArgument -Argument $_ }) -join ' ')
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo

        [void] $process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        [pscustomobject] @{
            ExitCode = $process.ExitCode
            Stdout = $stdout
            Stderr = $stderr
        }
    }

    function Invoke-NativeCommand {
        param(
            [Parameter(Mandatory = $true)]
            [string] $FilePath,

            [Parameter(Mandatory = $true)]
            [string[]] $Arguments,

            [Parameter(Mandatory = $true)]
            [string] $FailureMessage
        )

        $result = Invoke-NativeCapture -FilePath $FilePath -Arguments $Arguments
        if ($result.ExitCode -ne 0) {
            $details = $result.Stderr.Trim()
            if ($details) {
                throw "$FailureMessage Exit code: $($result.ExitCode). $details"
            }

            throw "$FailureMessage Exit code: $($result.ExitCode)"
        }

        return
    }

    function Get-SecretKeys {
        param(
            [Parameter(Mandatory = $true)]
            [string] $GpgPath
        )

        $result = Invoke-NativeCapture `
            -FilePath $GpgPath `
            -Arguments @('--batch', '--with-colons', '--list-secret-keys', '--fingerprint')

        if ($result.ExitCode -ne 0) {
            $details = $result.Stderr.Trim()
            if ($details) {
                throw "Failed to list existing GPG secret keys. Exit code: $($result.ExitCode). $details"
            }

            throw "Failed to list existing GPG secret keys. Exit code: $($result.ExitCode)"
        }

        $keys = New-Object 'System.Collections.Generic.List[object]'
        $currentKey = $null
        $expectPrimaryFingerprint = $false

        foreach ($line in ($result.Stdout -split "`r?`n")) {
            $fields = $line -split ':'
            if ($fields.Count -lt 10) {
                continue
            }

            if ($fields[0] -eq 'sec') {
                $currentKey = [pscustomobject] @{
                    Fingerprint = $null
                    KeyId = $fields[4]
                    UserIds = New-Object 'System.Collections.Generic.List[string]'
                    Emails = New-Object 'System.Collections.Generic.List[string]'
                }
                $expectPrimaryFingerprint = $true
                continue
            }

            if ($expectPrimaryFingerprint -and $fields[0] -eq 'fpr') {
                $currentKey.Fingerprint = $fields[9]
                $keys.Add($currentKey)
                $expectPrimaryFingerprint = $false
                continue
            }

            if ($currentKey -and $fields[0] -eq 'uid') {
                $userId = $fields[9]
                $currentKey.UserIds.Add($userId)

                $emailMatch = [regex]::Match($userId, '<([^>]+)>')
                if ($emailMatch.Success) {
                    $currentKey.Emails.Add($emailMatch.Groups[1].Value.ToLowerInvariant())
                }
            }
        }

        return $keys.ToArray()
    }

    function Get-SecretKeyFingerprints {
        param(
            [Parameter(Mandatory = $true)]
            [string] $GpgPath
        )

        return @(
            Get-SecretKeys -GpgPath $GpgPath |
                Where-Object { $_.Fingerprint } |
                ForEach-Object { $_.Fingerprint }
        )
    }

    function Get-MatchingSecretKeys {
        param(
            [Parameter(Mandatory = $true)]
            [string] $GpgPath,

            [Parameter(Mandatory = $true)]
            [string] $Email
        )

        $emailLower = $Email.ToLowerInvariant()
        return @(
            Get-SecretKeys -GpgPath $GpgPath |
                Where-Object { $_.Emails -contains $emailLower }
        )
    }

    function Remove-SecretAndPublicKey {
        param(
            [Parameter(Mandatory = $true)]
            [string] $GpgPath,

            [Parameter(Mandatory = $true)]
            [string] $Fingerprint
        )

        Invoke-NativeCommand `
            -FilePath $GpgPath `
            -Arguments @('--batch', '--yes', '--delete-secret-and-public-keys', $Fingerprint) `
            -FailureMessage "Failed to delete existing GPG key $Fingerprint."
    }

    function Format-KeyUserIds {
        param(
            [Parameter(Mandatory = $true)]
            [object] $Key
        )

        $userIds = @($Key.UserIds | Where-Object { $_ })
        if ($userIds.Count -eq 0) {
            return '(no user IDs)'
        }

        return ($userIds -join '; ')
    }

    function Assert-NoConflictingSecretKeys {
        param(
            [Parameter(Mandatory = $true)]
            [string] $GpgPath,

            [Parameter(Mandatory = $true)]
            [string] $Email,

            [Parameter(Mandatory = $true)]
            [bool] $ShouldReplace,

            [Parameter(Mandatory = $true)]
            [System.Management.Automation.PSCmdlet] $Cmdlet
        )

        $matchingKeys = @(Get-MatchingSecretKeys -GpgPath $GpgPath -Email $Email)
        if ($matchingKeys.Count -eq 0) {
            return
        }

        if (-not $ShouldReplace) {
            $matches = @(
                $matchingKeys |
                    ForEach-Object { "  - $($_.Fingerprint) $((Format-KeyUserIds -Key $_))" }
            ) -join [Environment]::NewLine

            throw "A local GPG secret key already exists for $Email.$([Environment]::NewLine)$matches$([Environment]::NewLine)Re-run with -ReplaceExisting to delete matching local keys first, or use the existing key instead."
        }

        foreach ($key in $matchingKeys) {
            $userIds = Format-KeyUserIds -Key $key
            Write-Warning "Deleting existing local GPG secret/public key $($key.Fingerprint): $userIds"

            if ($Cmdlet.ShouldProcess($key.Fingerprint, 'Delete existing local GPG secret/public key')) {
                Remove-SecretAndPublicKey -GpgPath $GpgPath -Fingerprint $key.Fingerprint
            }
        }
    }

    function ConvertTo-CompactText {
        param(
            [AllowNull()]
            [object] $Value
        )

        if ($null -eq $Value) {
            return $null
        }

        $text = $Value.ToString().Trim()
        if (-not $text) {
            return $null
        }

        return ($text -replace '\s+', ' ')
    }

    function Test-GenericHardwareValue {
        param(
            [AllowNull()]
            [string] $Value
        )

        if (-not $Value) {
            return $true
        }

        $genericValues = @(
            'Default string',
            'System Manufacturer',
            'System Product Name',
            'To Be Filled By O.E.M.',
            'To Be Filled By OEM'
        )

        return $genericValues -contains $Value
    }

    function ConvertTo-DisplayModel {
        param(
            [AllowNull()]
            [string] $Manufacturer,

            [AllowNull()]
            [string] $Model
        )

        $displayModel = ConvertTo-CompactText -Value $Model
        if (-not $displayModel) {
            return $null
        }

        if ($Manufacturer -and $displayModel -match ('^' + [regex]::Escape($Manufacturer) + '\s+')) {
            $displayModel = $displayModel.Substring($Manufacturer.Length).Trim()
        }

        $suffixPatterns = @(
            '\s+Mobile Workstation PC$',
            '\s+Workstation PC$',
            '\s+Notebook PC$',
            '\s+Laptop PC$',
            '\s+Desktop PC$',
            '\s+All-in-One PC$',
            '\s+PC$'
        )

        foreach ($suffixPattern in $suffixPatterns) {
            $displayModel = ($displayModel -replace $suffixPattern, '').Trim()
        }

        if (-not $displayModel) {
            return $null
        }

        return $displayModel
    }

    function Get-ComputerDescription {
        $machineName = ConvertTo-CompactText -Value $env:COMPUTERNAME
        $manufacturer = $null
        $model = $null

        try {
            $previousWhatIfPreference = $WhatIfPreference
            $WhatIfPreference = $false
            try {
                $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            }
            finally {
                $WhatIfPreference = $previousWhatIfPreference
            }

            $manufacturer = ConvertTo-CompactText -Value $computer.Manufacturer
            $model = ConvertTo-CompactText -Value $computer.Model
        }
        catch {
            $manufacturer = $null
            $model = $null
        }

        if (Test-GenericHardwareValue -Value $manufacturer) {
            $manufacturer = $null
        }

        if (Test-GenericHardwareValue -Value $model) {
            $model = $null
        }

        $displayModel = ConvertTo-DisplayModel -Manufacturer $manufacturer -Model $model
        $hardware = ConvertTo-CompactText -Value ((@($manufacturer, $displayModel) | Where-Object { $_ }) -join ' ')
        if ($hardware -and $machineName) {
            return "$hardware ($machineName)"
        }

        if ($hardware) {
            return $hardware
        }

        if ($machineName) {
            return $machineName
        }

        return 'Windows PC'
    }

    function New-GitHubKeyTitleSuggestion {
        param(
            [Parameter(Mandatory = $true)]
            [string] $OwnerName
        )

        $month = Get-Date -Format 'yyyy-MM'
        $computerDescription = Get-ComputerDescription
        return "$OwnerName - $computerDescription - Git signing - $month"
    }

    $enableCommitSigning = [bool] ($SignCommitsByDefault -or $EnableSigning)
    $enableTagSigning = [bool] ($SignTagsByDefault -or $EnableSigning)

    if (($enableCommitSigning -or $enableTagSigning) -and -not $ConfigureGit) {
        throw "-EnableSigning, -SignCommitsByDefault, and -SignTagsByDefault require -ConfigureGit."
    }

    $gpgPath = Resolve-RequiredCommand `
        -CommandName $GpgCommand `
        -InstallMessage 'Install Gpg4win or another GnuPG distribution, then reopen PowerShell.'

    $gitPath = $null
    if ($ConfigureGit) {
        $gitPath = Resolve-RequiredCommand `
            -CommandName $GitCommand `
            -InstallMessage 'Install Git for Windows, then reopen PowerShell.'
    }

    $gpgVersionResult = Invoke-NativeCapture -FilePath $gpgPath -Arguments @('--version')
    if ($gpgVersionResult.ExitCode -ne 0) {
        throw "Failed to run GPG. Exit code: $($gpgVersionResult.ExitCode). $($gpgVersionResult.Stderr.Trim())"
    }

    $gpgVersionText = ($gpgVersionResult.Stdout -split "`r?`n" | Select-Object -First 1)
    Write-Host "Using $gpgVersionText"

    $resolvedOutputDirectory = Resolve-Path -LiteralPath $OutputDirectory -ErrorAction SilentlyContinue
    if (-not $resolvedOutputDirectory) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        $resolvedOutputDirectory = Resolve-Path -LiteralPath $OutputDirectory
    }

    $userId = "$Name <$Email>"
    $gpgAlgorithm = if ($Algorithm -eq 'RSA4096') { 'rsa4096' } else { 'ed25519' }
    $githubKeyTitleSuggestion = New-GitHubKeyTitleSuggestion -OwnerName $Name

    Write-Host "Creating a new $Algorithm GPG key for $userId"
    Write-Host 'GPG may ask for a passphrase in a separate pinentry window.'
    Write-Host "Suggested GitHub key title: $githubKeyTitleSuggestion"

    if (-not $PSCmdlet.ShouldProcess($userId, 'Create GPG key')) {
        return
    }

    Assert-NoConflictingSecretKeys `
        -GpgPath $gpgPath `
        -Email $Email `
        -ShouldReplace ([bool] $ReplaceExisting) `
        -Cmdlet $PSCmdlet

    $beforeFingerprints = Get-SecretKeyFingerprints -GpgPath $gpgPath

    Invoke-NativeCommand `
        -FilePath $gpgPath `
        -Arguments @('--quick-generate-key', $userId, $gpgAlgorithm, 'cert,sign', $Expire) `
        -FailureMessage 'GPG key generation failed.'

    $afterFingerprints = Get-SecretKeyFingerprints -GpgPath $gpgPath
    $newFingerprints = @($afterFingerprints | Where-Object { $beforeFingerprints -notcontains $_ })

    if ($newFingerprints.Count -eq 0) {
        throw 'Could not identify the newly created key fingerprint. Run "gpg --list-secret-keys --keyid-format=long" and configure the key manually.'
    }

    if ($newFingerprints.Count -gt 1) {
        Write-Warning 'More than one new primary key appeared. Using the last fingerprint reported by GPG.'
    }

    $fingerprint = $newFingerprints[-1]
    $keyId = $fingerprint.Substring($fingerprint.Length - 16)
    $safeEmail = ($Email -replace '[^A-Za-z0-9._-]', '_')
    $publicKeyPath = Join-Path -Path $resolvedOutputDirectory.Path -ChildPath "github-gpg-$safeEmail-$keyId.asc"

    $publicKeyResult = Invoke-NativeCapture -FilePath $gpgPath -Arguments @('--armor', '--export', $fingerprint)
    if ($publicKeyResult.ExitCode -ne 0) {
        $details = $publicKeyResult.Stderr.Trim()
        if ($details) {
            throw "Failed to export the public GPG key. Exit code: $($publicKeyResult.ExitCode). $details"
        }

        throw "Failed to export the public GPG key. Exit code: $($publicKeyResult.ExitCode)"
    }

    $publicKey = $publicKeyResult.Stdout
    $publicKey | Set-Content -LiteralPath $publicKeyPath -Encoding ascii

    if (-not $NoClipboard) {
        $setClipboard = Get-Command Set-Clipboard -ErrorAction SilentlyContinue
        if ($setClipboard) {
            $publicKey | Set-Clipboard
            Write-Host 'Copied the public GPG key to the clipboard.'
        }
        else {
            Write-Warning 'Set-Clipboard is not available in this shell. The public key was saved to disk instead.'
        }
    }

    $gitConfigCommands = New-Object 'System.Collections.Generic.List[string]'

    if ($ConfigureGit) {
        Write-Host 'Configuring global Git signing settings.'

        $gpgFormatResult = Invoke-NativeCapture -FilePath $gitPath -Arguments @('config', '--global', '--get', 'gpg.format')
        $gpgFormat = $gpgFormatResult.Stdout.Trim()
        if ($gpgFormatResult.ExitCode -eq 0 -and $gpgFormat -and $gpgFormat -ne 'openpgp') {
            $gitConfigArguments = @('config', '--global', '--unset', 'gpg.format')
            Invoke-NativeCommand `
                -FilePath $gitPath `
                -Arguments $gitConfigArguments `
                -FailureMessage 'Failed to unset git config gpg.format.'

            $gitConfigCommands.Add((Format-DisplayCommand -Command $GitCommand -Arguments $gitConfigArguments))
        }

        $gitConfigArguments = @('config', '--global', 'gpg.program', $gpgPath)
        Invoke-NativeCommand `
            -FilePath $gitPath `
            -Arguments $gitConfigArguments `
            -FailureMessage 'Failed to configure git config gpg.program.'

        $gitConfigCommands.Add((Format-DisplayCommand -Command $GitCommand -Arguments $gitConfigArguments))

        $gitConfigArguments = @('config', '--global', 'user.signingkey', "$fingerprint!")
        Invoke-NativeCommand `
            -FilePath $gitPath `
            -Arguments $gitConfigArguments `
            -FailureMessage 'Failed to configure git config user.signingkey.'

        $gitConfigCommands.Add((Format-DisplayCommand -Command $GitCommand -Arguments $gitConfigArguments))

        if ($enableCommitSigning) {
            $gitConfigArguments = @('config', '--global', 'commit.gpgsign', 'true')
            Invoke-NativeCommand `
                -FilePath $gitPath `
                -Arguments $gitConfigArguments `
                -FailureMessage 'Failed to configure git config commit.gpgsign.'

            $gitConfigCommands.Add((Format-DisplayCommand -Command $GitCommand -Arguments $gitConfigArguments))
        }

        if ($enableTagSigning) {
            $gitConfigArguments = @('config', '--global', 'tag.gpgSign', 'true')
            Invoke-NativeCommand `
                -FilePath $gitPath `
                -Arguments $gitConfigArguments `
                -FailureMessage 'Failed to configure git config tag.gpgSign.'

            $gitConfigCommands.Add((Format-DisplayCommand -Command $GitCommand -Arguments $gitConfigArguments))
        }
    }

    Write-Host ''
    Write-Host 'Created GPG key.'
    Write-Host "Fingerprint: $fingerprint"
    Write-Host "Key ID:      $keyId"
    Write-Host "Public key:  $publicKeyPath"
    Write-Host "GitHub key title suggestion: $githubKeyTitleSuggestion"
    if ($ConfigureGit) {
        Write-Host ''
        Write-Host 'Git configuration applied:'
        foreach ($gitConfigCommand in $gitConfigCommands) {
            Write-Host "   $gitConfigCommand"
        }
    }
    Write-Host ''
    Write-Host 'Next steps:'
    Write-Host '1. Add the public key to GitHub: https://github.com/settings/keys'
    Write-Host "   Suggested title: $githubKeyTitleSuggestion"
    Write-Host '2. Use the same verified email address for Git commits:'
    Write-Host "   git config --global user.email `"$Email`""
    if (-not $ConfigureGit) {
        Write-Host '3. Configure Git to use this signing key:'
        Write-Host "   $(Format-DisplayCommand -Command $GitCommand -Arguments @('config', '--global', 'gpg.program', $gpgPath))"
        Write-Host "   $(Format-DisplayCommand -Command $GitCommand -Arguments @('config', '--global', 'user.signingkey', "$fingerprint!"))"
        Write-Host "   $(Format-DisplayCommand -Command $GitCommand -Arguments @('config', '--global', 'commit.gpgsign', 'true'))"
        Write-Host "   $(Format-DisplayCommand -Command $GitCommand -Arguments @('config', '--global', 'tag.gpgSign', 'true'))"
    }
    Write-Host ''
    Write-Host 'To test signing after adding the key to GitHub:'
    Write-Host '   git commit --allow-empty -S -m "test signed commit"'
}
