# Git Utilities
# Functions related to Git operations

function Get-GitCommitAnalysis {
    <#
    .SYNOPSIS
    Analyzes git repository commits and counts occurrences of specified strings.

    .DESCRIPTION
    Lists all repository commits using a detailed git log format and counts commits
    that contain the specified search strings. Provides a comprehensive report with
    statistics including total commits, matches per string, and percentages.
    Uses ripgrep for better performance if available, otherwise falls back to Select-String.

    .PARAMETER SearchStrings
    One or more strings to search for in the git commit output.

    .PARAMETER Repository
    Path to the git repository. Defaults to current directory.

    .EXAMPLE
    Get-GitCommitAnalysis -SearchStrings "John Doe"

    .EXAMPLE
    Get-GitCommitAnalysis -SearchStrings @("John Doe", "jane.smith@example.com", "bugfix")

    .EXAMPLE
    Get-GitCommitAnalysis -SearchStrings "feature" -Repository "C:\Projects\MyRepo"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$SearchStrings,

        [Parameter(Position = 1)]
        [string]$Repository = '.'
    )

    begin {
        # Check if we're in a git repository
        $originalLocation = Get-Location
        try {
            Set-Location $Repository
            $null = git rev-parse --git-dir 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw 'Not a git repository or git not found'
            }
        }
        catch {
            Set-Location $originalLocation
            throw "Error: $($_.Exception.Message)"
        }

        # Check if ripgrep is available
        $useRipgrep = $null -ne (Get-Command rg -ErrorAction SilentlyContinue)

        # Git log format from your baseline
        $gitLogFormat = "--graph --no-abbrev-commit --boundary --pretty=format:'[%aN <%aE>]%Creset'"
    }

    process {
        try {
            Write-Host '🔍 Analyzing git repository...' -ForegroundColor Cyan
            Write-Host "📂 Repository: $(Resolve-Path $Repository)" -ForegroundColor Gray
            Write-Host "🔧 Search tool: $(if ($useRipgrep) { 'ripgrep (rg)' } else { 'Select-String' })" -ForegroundColor Gray
            Write-Host ''

            # Get all commits
            Write-Host '📊 Fetching commit history...' -ForegroundColor Yellow
            $gitLogCommand = "git log $gitLogFormat"
            $allCommits = Invoke-Expression $gitLogCommand

            if (-not $allCommits) {
                Write-Warning 'No commits found in the repository'
                return
            }

            # Convert to array if it's a single string
            if ($allCommits -is [string]) {
                $allCommits = @($allCommits)
            }

            $totalCommits = $allCommits.Count
            Write-Host "✅ Found $totalCommits total commits" -ForegroundColor Green
            Write-Host ''

            # Initialize results
            $results = @{}
            $totalMatches = 0

            # Search for each string
            foreach ($searchString in $SearchStrings) {
                Write-Host "🔎 Searching for: '$searchString'" -ForegroundColor Cyan

                if ($useRipgrep) {
                    # Use ripgrep for case-insensitive search
                    $commitMatches = $allCommits | rg -i $searchString
                }
                else {
                    # Fallback to Select-String
                    $commitMatches = $allCommits | Select-String -Pattern $searchString -AllMatches
                }

                $matchCount = if ($commitMatches) {
                    if ($commitMatches -is [array]) { $commitMatches.Count } else { 1 }
                }
                else { 0 }

                $results[$searchString] = $matchCount
                $totalMatches += $matchCount

                Write-Host "   Found $matchCount matches" -ForegroundColor $(if ($matchCount -gt 0) { 'Green' } else { 'Yellow' })
            }

            # Generate report
            Write-Host ''
            Write-Host $('=' * 80) -ForegroundColor Magenta
            Write-Host '📋 COMMIT ANALYSIS REPORT' -ForegroundColor Magenta
            Write-Host $('=' * 80) -ForegroundColor Magenta
            Write-Host ''

            # Summary statistics
            Write-Host '📊 SUMMARY' -ForegroundColor Yellow
            Write-Host "   Total commits in repository: $totalCommits" -ForegroundColor White
            Write-Host "   Total matches found: $totalMatches" -ForegroundColor White
            Write-Host "   Overall match percentage: $([math]::Round(($totalMatches / $totalCommits) * 100, 2))%" -ForegroundColor White
            Write-Host "   Search strings analyzed: $($SearchStrings.Count)" -ForegroundColor White
            Write-Host ''

            # Detailed breakdown
            Write-Host '🔍 DETAILED BREAKDOWN' -ForegroundColor Yellow
            $searchResults = @()

            foreach ($searchString in $SearchStrings) {
                $count = $results[$searchString]
                $percentage = if ($totalCommits -gt 0) { [math]::Round(($count / $totalCommits) * 100, 2) } else { 0 }
                $percentageOfMatches = if ($totalMatches -gt 0) { [math]::Round(($count / $totalMatches) * 100, 2) } else { 0 }

                $searchResults += [PSCustomObject]@{
                    SearchString        = $searchString
                    Matches             = $count
                    PercentageOfTotal   = "$percentage%"
                    PercentageOfMatches = "$percentageOfMatches%"
                }

                $color = switch ($count) {
                    0 { 'Red' }
                    { $_ -lt 5 } { 'Yellow' }
                    { $_ -lt 20 } { 'Cyan' }
                    default { 'Green' }
                }

                Write-Host "   '$searchString'" -ForegroundColor White -NoNewline
                Write-Host ' → ' -ForegroundColor Gray -NoNewline
                Write-Host "$count matches " -ForegroundColor $color -NoNewline
                Write-Host "($percentage% of total, $percentageOfMatches% of matches)" -ForegroundColor Gray
            }

            # Table format for better readability
            Write-Host ''
            Write-Host '📋 TABULAR SUMMARY' -ForegroundColor Yellow
            $searchResults | Format-Table -AutoSize

            # Additional insights
            Write-Host '💡 INSIGHTS' -ForegroundColor Yellow
            $mostMatches = $results.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
            $leastMatches = $results.GetEnumerator() | Sort-Object Value | Select-Object -First 1

            if ($mostMatches.Value -gt 0) {
                Write-Host "   🏆 Most matches: '$($mostMatches.Key)' with $($mostMatches.Value) matches" -ForegroundColor Green
            }
            if ($leastMatches.Value -lt $mostMatches.Value) {
                Write-Host "   📉 Least matches: '$($leastMatches.Key)' with $($leastMatches.Value) matches" -ForegroundColor Yellow
            }

            $averageMatches = [math]::Round($totalMatches / $SearchStrings.Count, 2)
            Write-Host "   📊 Average matches per search string: $averageMatches" -ForegroundColor Cyan

            Write-Host ''
            Write-Host $('=' * 80) -ForegroundColor Magenta

            # Return structured data
            return [PSCustomObject]@{
                Repository        = (Resolve-Path $Repository).Path
                TotalCommits      = $totalCommits
                TotalMatches      = $totalMatches
                OverallPercentage = [math]::Round(($totalMatches / $totalCommits) * 100, 2)
                SearchResults     = $searchResults
                SearchTool        = if ($useRipgrep) { 'ripgrep' } else { 'Select-String' }
                Timestamp         = Get-Date
            }
        }
        catch {
            Write-Error "An error occurred: $($_.Exception.Message)"
        }
        finally {
            Set-Location $originalLocation
        }
    }
}
Set-Alias -Name count-commits -Value Get-GitCommitAnalysis

function Get-GitCodeContributions {
    <#
    .SYNOPSIS
    Analyzes git repository code contributions and counts lines of code written per author.

    .DESCRIPTION
    Analyzes git repository commits to calculate lines of code added, removed, and net changes
    per author. Provides comprehensive statistics including total contributions, percentages,
    and detailed breakdowns. Can filter by specific authors or analyze all contributors.

    .PARAMETER Authors
    One or more author names or email addresses to analyze. If not specified, analyzes all authors.
    Supports partial matching (case-insensitive).

    .PARAMETER Repository
    Path to the git repository. Defaults to current directory.

    .PARAMETER SinceDate
    Only analyze commits since this date. Format: YYYY-MM-DD

    .PARAMETER UntilDate
    Only analyze commits until this date. Format: YYYY-MM-DD

    .PARAMETER IncludeFileTypes
    Only analyze specific file types (extensions). Example: @("ps1", "cs", "js")

    .EXAMPLE
    Get-GitCodeContributions

    .EXAMPLE
    Get-GitCodeContributions -Authors @("John Doe", "jane.smith@example.com")

    .EXAMPLE
    Get-GitCodeContributions -SinceDate "2024-01-01" -IncludeFileTypes @("ps1", "py")

    .EXAMPLE
    Get-GitCodeContributions -Authors "John Doe" -Repository "C:\Projects\MyRepo"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string[]]$Authors,

        [Parameter(Position = 1)]
        [string]$Repository = '.',

        [Parameter()]
        [string]$SinceDate,

        [Parameter()]
        [string]$UntilDate,

        [Parameter()]
        [string[]]$IncludeFileTypes
    )

    begin {
        # Check if we're in a git repository
        $originalLocation = Get-Location
        try {
            Set-Location $Repository
            $null = git rev-parse --git-dir 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw 'Not a git repository or git not found'
            }
        }
        catch {
            Set-Location $originalLocation
            throw "Error: $($_.Exception.Message)"
        }
    }

    process {
        try {
            Write-Host ' Analyzing code contributions...' -ForegroundColor Cyan
            Write-Host " Repository: $(Resolve-Path $Repository)" -ForegroundColor Gray
            if ($SinceDate) { Write-Host " Since: $SinceDate" -ForegroundColor Gray }
            if ($UntilDate) { Write-Host " Until: $UntilDate" -ForegroundColor Gray }
            if ($IncludeFileTypes) { Write-Host " File types: $($IncludeFileTypes -join ', ')" -ForegroundColor Gray }
            Write-Host ''

            # Build git log command
            $gitLogCommand = "git log --numstat --pretty=format:'COMMIT:%H|%an|%ae|%ad' --date=iso8601-strict"

            if ($SinceDate) { $gitLogCommand += " --since='$SinceDate'" }
            if ($UntilDate) { $gitLogCommand += " --until='$UntilDate'" }

            Write-Host ' Fetching commit statistics...' -ForegroundColor Yellow
            $logOutput = Invoke-Expression $gitLogCommand

            if (-not $logOutput) {
                Write-Warning 'No commits found matching the criteria'
                return
            }

            # Parse the output
            $authorStats = @{}
            $currentAuthor = $null
            $totalAdditions = 0
            $totalDeletions = 0

            Write-Host ' Processing commit data...' -ForegroundColor Yellow

            foreach ($line in $logOutput) {
                if ($line -match '^COMMIT:(.+)\|(.+)\|(.+)\|(.+)$') {
                    $currentAuthor = $Matches[2].Trim()
                    $authorEmail = $Matches[3].Trim()

                    # Initialize author if not exists
                    if (-not $authorStats.ContainsKey($currentAuthor)) {
                        $authorStats[$currentAuthor] = @{
                            Name         = $currentAuthor
                            Email        = $authorEmail
                            Additions    = 0
                            Deletions    = 0
                            NetChanges   = 0
                            Commits      = 0
                            FilesChanged = @{}
                        }
                    }
                    $authorStats[$currentAuthor].Commits++
                }
                elseif ($line -match '^(\d+)\s+(\d+)\s+(.+)$' -and $currentAuthor) {
                    $additions = [int]$Matches[1]
                    $deletions = [int]$Matches[2]
                    $fileName = $Matches[3]

                    # Filter by file types if specified
                    if ($IncludeFileTypes) {
                        $fileExtension = [System.IO.Path]::GetExtension($fileName).TrimStart('.')
                        if ($fileExtension -notin $IncludeFileTypes) {
                            continue
                        }
                    }

                    # Update author statistics
                    $authorStats[$currentAuthor].Additions += $additions
                    $authorStats[$currentAuthor].Deletions += $deletions
                    $authorStats[$currentAuthor].NetChanges += ($additions - $deletions)

                    # Track files changed
                    if (-not $authorStats[$currentAuthor].FilesChanged.ContainsKey($fileName)) {
                        $authorStats[$currentAuthor].FilesChanged[$fileName] = 0
                    }
                    $authorStats[$currentAuthor].FilesChanged[$fileName]++

                    $totalAdditions += $additions
                    $totalDeletions += $deletions
                }
            }

            # Filter by authors if specified
            if ($Authors) {
                $filteredStats = @{}
                foreach ($author in $Authors) {
                    foreach ($key in $authorStats.Keys) {
                        if ($key -like "*$author*" -or $authorStats[$key].Email -like "*$author*") {
                            $filteredStats[$key] = $authorStats[$key]
                        }
                    }
                }
                $authorStats = $filteredStats
            }

            if ($authorStats.Count -eq 0) {
                Write-Warning 'No matching authors found'
                return
            }

            # Generate report
            Write-Host ''
            Write-Host $('=' * 80) -ForegroundColor Magenta
            Write-Host ' CODE CONTRIBUTIONS ANALYSIS' -ForegroundColor Magenta
            Write-Host $('=' * 80) -ForegroundColor Magenta
            Write-Host ''

            # Summary statistics
            Write-Host ' SUMMARY' -ForegroundColor Yellow
            $totalCommits = ($authorStats.Values | Measure-Object -Property Commits -Sum).Sum
            $totalNet = $totalAdditions - $totalDeletions
            Write-Host "   Total authors analyzed: $($authorStats.Count)" -ForegroundColor White
            Write-Host "   Total commits: $totalCommits" -ForegroundColor White
            Write-Host "   Total lines added: $totalAdditions" -ForegroundColor Green
            Write-Host "   Total lines deleted: $totalDeletions" -ForegroundColor Red
            Write-Host "   Net lines of code: $totalNet" -ForegroundColor $(if ($totalNet -gt 0) { 'Green' } else { 'Red' })
            Write-Host ''

            # Detailed breakdown
            Write-Host ' DETAILED BREAKDOWN' -ForegroundColor Yellow
            $contributionResults = @()

            $sortedAuthors = $authorStats.GetEnumerator() | Sort-Object { $_.Value.NetChanges } -Descending

            foreach ($authorEntry in $sortedAuthors) {
                $author = $authorEntry.Value
                $additionsPercent = if ($totalAdditions -gt 0) { [math]::Round(($author.Additions / $totalAdditions) * 100, 2) } else { 0 }
                $deletionsPercent = if ($totalDeletions -gt 0) { [math]::Round(($author.Deletions / $totalDeletions) * 100, 2) } else { 0 }
                $commitsPercent = if ($totalCommits -gt 0) { [math]::Round(($author.Commits / $totalCommits) * 100, 2) } else { 0 }

                $contributionResults += [PSCustomObject]@{
                    Author        = $author.Name
                    Email         = $author.Email
                    Commits       = $author.Commits
                    LinesAdded    = $author.Additions
                    LinesDeleted  = $author.Deletions
                    NetLines      = $author.NetChanges
                    FilesModified = $author.FilesChanged.Count
                    CommitShare   = "$commitsPercent%"
                    AdditionShare = "$additionsPercent%"
                    DeletionShare = "$deletionsPercent%"
                }

                $netColor = if ($author.NetChanges -gt 0) { 'Green' } elseif ($author.NetChanges -lt 0) { 'Red' } else { 'Yellow' }

                Write-Host "   $($author.Name)" -ForegroundColor White -NoNewline
                Write-Host " [$($author.Email)]" -ForegroundColor Gray
                Write-Host "     Commits: $($author.Commits) ($commitsPercent%)" -ForegroundColor Cyan
                Write-Host '     Lines added: ' -ForegroundColor Gray -NoNewline
                Write-Host "$($author.Additions)" -ForegroundColor Green -NoNewline
                Write-Host ' | Lines deleted: ' -ForegroundColor Gray -NoNewline
                Write-Host "$($author.Deletions)" -ForegroundColor Red -NoNewline
                Write-Host ' | Net: ' -ForegroundColor Gray -NoNewline
                Write-Host "$($author.NetChanges)" -ForegroundColor $netColor
                Write-Host "     Files modified: $($author.FilesChanged.Count)" -ForegroundColor Yellow
                Write-Host ''
            }

            # Table format
            Write-Host ' TABULAR SUMMARY' -ForegroundColor Yellow
            $contributionResults | Format-Table -AutoSize

            # Additional insights
            Write-Host ' INSIGHTS' -ForegroundColor Yellow
            $topContributor = $sortedAuthors | Select-Object -First 1
            $mostCommits = $authorStats.GetEnumerator() | Sort-Object { $_.Value.Commits } -Descending | Select-Object -First 1
            $mostFilesChanged = $authorStats.GetEnumerator() | Sort-Object { $_.Value.FilesChanged.Count } -Descending | Select-Object -First 1

            if ($topContributor) {
                Write-Host "    Top contributor (net lines): $($topContributor.Value.Name) with $($topContributor.Value.NetChanges) lines" -ForegroundColor Green
            }
            if ($mostCommits) {
                Write-Host "    Most commits: $($mostCommits.Value.Name) with $($mostCommits.Value.Commits) commits" -ForegroundColor Cyan
            }
            if ($mostFilesChanged) {
                Write-Host "    Most files modified: $($mostFilesChanged.Value.Name) with $($mostFilesChanged.Value.FilesChanged.Count) files" -ForegroundColor Yellow
            }

            $avgLinesPerCommit = if ($totalCommits -gt 0) { [math]::Round($totalNet / $totalCommits, 2) } else { 0 }
            Write-Host "    Average net lines per commit: $avgLinesPerCommit" -ForegroundColor Magenta

            Write-Host ''
            Write-Host $('=' * 80) -ForegroundColor Magenta

            # Return structured data
            return [PSCustomObject]@{
                Repository          = (Resolve-Path $Repository).Path
                TotalAuthors        = $authorStats.Count
                TotalCommits        = $totalCommits
                TotalLinesAdded     = $totalAdditions
                TotalLinesDeleted   = $totalDeletions
                NetLinesOfCode      = $totalNet
                ContributionResults = $contributionResults
                DateRange           = @{
                    Since = $SinceDate
                    Until = $UntilDate
                }
                FileTypesFilter     = $IncludeFileTypes
                Timestamp           = Get-Date
            }
        }
        catch {
            Write-Error "An error occurred: $($_.Exception.Message)"
        }
        finally {
            Set-Location $originalLocation
        }
    }
}

# Alias for shorter usage
Set-Alias -Name count-loc -Value Get-GitCodeContributions