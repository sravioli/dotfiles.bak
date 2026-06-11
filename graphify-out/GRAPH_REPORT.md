# Graph Report - .  (2026-06-11)

## Corpus Check
- Corpus is ~30,949 words - fits in a single context window. You may not need a graph.

## Summary
- 136 nodes · 145 edges · 25 communities (24 shown, 1 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.81)
- Token cost: 5,500 input · 2,200 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Terminal Color Palette|Terminal Color Palette]]
- [[_COMMUNITY_Oh My Posh Prompt Theme|Oh My Posh Prompt Theme]]
- [[_COMMUNITY_Shell Completion Manager|Shell Completion Manager]]
- [[_COMMUNITY_Scheduled Task Automation|Scheduled Task Automation]]
- [[_COMMUNITY_Git Aliases & Task Concepts|Git Aliases & Task Concepts]]
- [[_COMMUNITY_Package & Dotfiles Provisioning|Package & Dotfiles Provisioning]]
- [[_COMMUNITY_Filesystem & Utility Functions|Filesystem & Utility Functions]]
- [[_COMMUNITY_Android ADB Tools|Android ADB Tools]]

## God Nodes (most connected - your core abstractions)
1. `palette` - 27 edges
2. `Write-ColorOutput()` - 9 edges
3. `Package & Extension Manifest` - 7 edges
4. `Get-CompletionRoot()` - 6 edges
5. `Get-TaskConfiguration()` - 6 edges
6. `Get-EventFolders()` - 6 edges
7. `Invoke-CreateTasks()` - 6 edges
8. `GitAlias.com Alias Collection` - 6 edges
9. `PowerShell Task Management System` - 6 edges
10. `Read-CompletionManifest()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Chezmoi Bootstrap Process` --references--> `Package & Extension Manifest`  [INFERRED]
  README.md → .chezmoidata/packages.yaml
- `Dotfiles Repository README` --conceptually_related_to--> `GitAlias.com Alias Collection`  [INFERRED]
  README.md → dot_config/git/gitalias.txt
- `Work vs Personal Machine Model` --rationale_for--> `Windows Work-Laptop Apps`  [INFERRED]
  README.md → .chezmoidata/packages.yaml
- `Remove-Completion()` --calls--> `Get-CompletionRoot()`  [INFERRED]
  dot_config/powershell/Modules/CompletionManager/Public/Remove-Completion.ps1 → dot_config/powershell/Modules/CompletionManager/Private/Get-CompletionRoot.ps1
- `Dotfiles Repository README` --references--> `Package & Extension Manifest`  [EXTRACTED]
  README.md → .chezmoidata/packages.yaml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Cross-Platform Package Installation** — chezmoidata_packages_manifest, chezmoidata_packages_winget, chezmoidata_packages_apt, chezmoidata_packages_cargo [INFERRED 0.95]
- **PowerShell Task Execution System** — tasks_readme_create_ps1, tasks_readme_taskhelpers, tasks_readme_three_tier_config [EXTRACTED 1.00]
- **Chezmoi Machine Initialization Flow** — readme_chezmoi_bootstrap, readme_work_personal_split, chezmoidata_packages_wingetwork [INFERRED 0.85]

## Communities (25 total, 1 thin omitted)

### Community 0 - "Terminal Color Palette"
Cohesion: 0.07
Nodes (27): palette, black, blue, bright-black, bright-blue, bright-cyan, bright-green, bright-magenta (+19 more)

### Community 1 - "Oh My Posh Prompt Theme"
Cohesion: 0.10
Nodes (19): blocks, console_title_template, error_line, background, foreground, template, final_space, pwd (+11 more)

### Community 2 - "Shell Completion Manager"
Cohesion: 0.16
Nodes (8): Get-CompletionRoot(), Read-CompletionManifest(), Write-CompletionManifest(), Initialize-Completion(), Remove-Completion(), Save-Completion(), Test-Completion(), Update-Completions()

### Community 3 - "Scheduled Task Automation"
Cohesion: 0.42
Nodes (11): Get-EventFolders(), Get-TaskConfiguration(), Invoke-CreateTasks(), Invoke-ListTasks(), Invoke-RemoveTasks(), Invoke-ValidateFolders(), Merge-Hashtables(), New-ScheduledTaskFromConfig() (+3 more)

### Community 4 - "Git Aliases & Task Concepts"
Cohesion: 0.20
Nodes (12): Branch Aliases Group, GitAlias.com Alias Collection, Commit Aliases Group, Log Aliases Group, Short Command Aliases, Create.ps1 Management Script, Task Skip Mechanism, PowerShell Task Management System (+4 more)

### Community 5 - "Package & Dotfiles Provisioning"
Cohesion: 0.27
Nodes (10): Linux APT Packages, Linux Cargo Packages, Package & Extension Manifest, VS Code Extensions List, Windows Winget Packages, Windows Work-Laptop Apps, Dotfiles Repository README, Chezmoi Bootstrap Process (+2 more)

### Community 8 - "Android ADB Tools"
Cohesion: 0.83
Nodes (3): Get-AdbDevices(), Install-APK(), Uninstall-APK()

## Knowledge Gaps
- **53 isolated node(s):** `$schema`, `black`, `blue`, `bright-black`, `bright-blue` (+48 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `palette` connect `Terminal Color Palette` to `Oh My Posh Prompt Theme`?**
  _High betweenness centrality (0.093) - this node is a cross-community bridge._
- **Why does `GitAlias.com Alias Collection` connect `Git Aliases & Task Concepts` to `Package & Dotfiles Provisioning`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `Get-CompletionRoot()` (e.g. with `Initialize-Completion()` and `Remove-Completion()`) actually correct?**
  _`Get-CompletionRoot()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **What connects `$schema`, `black`, `blue` to the rest of the system?**
  _53 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Terminal Color Palette` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Should `Oh My Posh Prompt Theme` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._