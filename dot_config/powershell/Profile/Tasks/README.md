# 📚 PowerShell Task Management System

> **A unified system for creating and managing event-driven Windows scheduled tasks.**

---

## 📋 Table of Contents

- [Quick Start](#-quick-start-5-minutes)
- [Overview](#-overview)
- [Folder Structure](#-folder-structure)
- [Configuration](#-configuration)
- [Creating Tasks](#-creating-tasks)
- [Examples](#-examples)
- [Troubleshooting](#-troubleshooting)
- [Reference](#-reference)

---

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- Windows 10/11
- PowerShell 7+
- Administrator privileges

### Create Your First Task

```powershell
# 1. Navigate to Tasks directory
cd "$HOME\.config\powershell\Profile\Tasks"

# 2. Copy the template
Copy-Item "_template" "my-task" -Recurse
cd my-task

# 3. Remove .skip file to enable processing
Remove-Item .skip

# 4. Edit your files
code Run.ps1          # Your task logic
code .env             # Your configuration
code task.config.json # Trigger settings

# 5. Create the scheduled task
cd ..
.\Create.ps1 -Action Create -FolderName "my-task" -Verbose

# 6. Test it
Start-ScheduledTask -TaskName "ProfileTask_my-task"
```

### Management Commands

```powershell
# Create all tasks
.\Create.ps1 -Action Create

# Create specific task
.\Create.ps1 -Action Create -FolderName "my-task"

# Recreate existing task (force)
.\Create.ps1 -Action Create -FolderName "my-task" -Force

# List all tasks
.\Create.ps1 -Action List

# Remove task
.\Create.ps1 -Action Remove -FolderName "my-task"

# Validate folder structure
.\Create.ps1 -Action Validate
```

---

## 🎯 Overview

This system provides a centralized way to manage Windows scheduled tasks using a single `Create.ps1` script.

### Key Features

✅ **Single script management** - One script manages all tasks  
✅ **Automatic discovery** - Scans directories for valid task folders  
✅ **Flexible configuration** - Three-tier configuration system  
✅ **Multiple triggers** - Event, time-based, logon, startup  
✅ **Silent execution** - No popup windows  
✅ **Built-in validation** - Validates folder structure  
✅ **Skip mechanism** - Easy way to exclude folders  
✅ **Shared libraries** - Reusable utility functions

### How It Works

1. **Create folders** - Each task lives in its own folder
2. **Add files** - Minimum: `Run.ps1` (your script)
3. **Configure** - Optional: `.env` and `task.config.json`
4. **Run Create.ps1** - Automatically creates Windows scheduled tasks
5. **Tasks run** - Triggered by events or schedule

---

## 📁 Folder Structure

```
Profile/Tasks/
├── Create.ps1                    # Main management script
├── .defaults.json                # Optional: Global defaults
│
├── _template/                    # Template for new tasks
│   ├── Run.ps1
│   ├── README.md
│   ├── .env
│   ├── task.config.json
│   └── .skip                     # Excluded from processing
│
├── _lib/                         # Shared libraries
│   └── TaskHelpers.psm1          # Utility functions
│
├── _docs/                        # Documentation
│   └── README.md                 # This file
│
└── auto-run-vpn/                 # Example task
    ├── Run.ps1                   # ✅ REQUIRED: Execution script
    ├── README.md                 # ⭐ RECOMMENDED: Documentation
    ├── .env                      # ⭐ OPTIONAL: Environment variables
    └── task.config.json          # ⭐ OPTIONAL: Task configuration
```

### Required Files
- **Run.ps1** - The script that executes when the task runs

### Optional Files
- **README.md** - Documentation for the task
- **.env** - Environment variables (loaded automatically)
- **task.config.json** - Task-specific configuration overrides
- **.skip** - Excludes folder from task creation

---

## ⚙️ Configuration

### Three-Tier System

Configuration merges in this order (highest priority last):

```
1. Built-in Defaults (in Create.ps1)
           ↓ (overrides)
2. Global Defaults (.defaults.json) 
           ↓ (overrides)
3. Task-Specific (task.config.json)
```

### task.config.json Structure

Minimal configuration (only specify what differs from defaults):

```json
{
  "trigger": {
    "type": "event",
    "eventLog": "Microsoft-Windows-WLAN-AutoConfig/Operational",
    "eventId": 8003,
    "provider": "Microsoft-Windows-WLAN-AutoConfig"
  }
}
```

Full configuration example:

```json
{
  "trigger": {
    "type": "event",
    "eventLog": "Microsoft-Windows-WLAN-AutoConfig/Operational",
    "eventId": 8003,
    "provider": "Microsoft-Windows-WLAN-AutoConfig"
  },
  "settings": {
    "allowStartIfOnBatteries": true,
    "dontStopIfGoingOnBatteries": true,
    "startWhenAvailable": true,
    "dontStopOnIdleEnd": true,
    "executionTimeLimit": "00:05:00",
    "hidden": false
  },
  "execution": {
    "executable": "pwsh.exe",
    "baseArguments": "-NonInteractive -NoProfile -ExecutionPolicy Bypass",
    "additionalArguments": "-Verbose"
  },
  "taskNameTemplate": "TaskName_{FolderName}",
  "descriptionTemplate": "Description for {FolderName}"
}
```

### Configuration Reference

#### Trigger Types

| Type | Required Fields | Use Case |
|------|----------------|----------|
| `event` | eventLog, eventId, provider | Wi-Fi connect, USB insert |
| `time` | intervalMinutes | Periodic tasks (every N minutes) |
| `logon` | (none) | User login tasks |
| `startup` | (none) | System startup tasks |

#### Common Settings

| Setting | Type | Default | Example | Notes |
|---------|------|---------|---------|-------|
| `executionTimeLimit` | TimeSpan | `01:00:00` | `"00:05:00"` | **Must use HH:MM:SS format** |
| `hidden` | Boolean | `true` | `false` | `false` = visible window (for debugging) |
| `allowStartIfOnBatteries` | Boolean | `true` | `true` | Run on battery power |
| `startWhenAvailable` | Boolean | `true` | `true` | Run if missed |

#### TimeSpan Format ⚠️ IMPORTANT

**Always use `HH:MM:SS` format in JSON config**

| Duration | ✅ Correct Format | ❌ Wrong (ISO 8601) |
|----------|----------------|---------------------|
| 30 seconds | `"00:00:30"` | ~~PT30S~~ |
| 5 minutes | `"00:05:00"` | ~~PT5M~~ |
| 30 minutes | `"00:30:00"` | ~~PT30M~~ |
| 1 hour | `"01:00:00"` | ~~PT1H~~ |
| 2 hours | `"02:00:00"` | ~~PT2H~~ |
| No limit | `"00:00:00"` | ~~PT0S~~ |

> **Why?** PowerShell cmdlets require TimeSpan format (`HH:MM:SS`), not ISO 8601 format (`PT5M`). ISO 8601 is used in Task Scheduler XML but not in PowerShell JSON configs.

#### Common Event Logs

| Event | Log Name | Event ID | Description |
|-------|----------|----------|-------------|
| Wi-Fi Connected | `Microsoft-Windows-WLAN-AutoConfig/Operational` | 8003 | Successfully connected to network |
| Wi-Fi Disconnected | `Microsoft-Windows-WLAN-AutoConfig/Operational` | 8001 | Disconnected from network |
| Network Connected | `Microsoft-Windows-NetworkProfile/Operational` | 10000 | Network profile connected |
| User Logon | `Security` | 4624 | Successful logon |
| User Logoff | `Security` | 4634 | Successful logoff |

**Find event IDs:**
```powershell
# View recent events
Get-WinEvent -LogName "Microsoft-Windows-WLAN-AutoConfig/Operational" -MaxEvents 20

# Find specific event
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-WLAN-AutoConfig/Operational'
    Id = 8003
} -MaxEvents 5
```

---

## 🔨 Creating Tasks

### Method 1: Using Template (Recommended)

```powershell
# 1. Copy template
Copy-Item "_template" "my-new-task" -Recurse
cd my-new-task

# 2. Remove .skip file (enables processing)
Remove-Item .skip

# 3. Edit Run.ps1
@'
[CmdletBinding()]
param()

# Import helpers
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) '_lib\TaskHelpers.psm1')

# Load environment
Import-TaskEnvironment

# Your logic here
Write-TaskLog "Task executed!" -Level Success
'@ | Out-File Run.ps1 -Encoding utf8

# 4. Edit .env
@'
MY_SETTING=value
APP_PATH=C:\path\to\app.exe
'@ | Out-File .env -Encoding utf8

# 5. Edit task.config.json (configure trigger)

# 6. Create task
cd ..
.\Create.ps1 -Action Create -FolderName "my-new-task"
```

### Method 2: From Scratch

```powershell
# 1. Create folder
mkdir my-task
cd my-task

# 2. Create Run.ps1 (minimum required)
@'
[CmdletBinding()]
param()

Write-Verbose "Task started at $(Get-Date)"

# Your task logic here
Write-Host "Hello from my task!" -ForegroundColor Green

Write-Verbose "Task completed"
'@ | Out-File Run.ps1 -Encoding utf8

# 3. Create README.md (recommended)
@'
# My Task

## Purpose
Brief description of what this task does.

## Configuration
- No special configuration required
'@ | Out-File README.md -Encoding utf8

# 4. Create task
cd ..
.\Create.ps1 -Action Create -FolderName "my-task"
```

---

## 📖 Examples

### Example 1: Wi-Fi Network Handler

**Purpose:** Auto-launch VPN and Outlook when connecting to home Wi-Fi

**Files:**
```
auto-run-vpn/
├── Run.ps1
├── .env
└── task.config.json
```

**.env:**
```bash
HOME_SSID=MyHomeNetwork
FORTICLIENT_PATH=C:\Program Files\Fortinet\FortiClient\FortiClient.exe
OUTLOOK_PATH=C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE
```

**task.config.json:**
```json
{
  "trigger": {
    "type": "event",
    "eventLog": "Microsoft-Windows-WLAN-AutoConfig/Operational",
    "eventId": 8003,
    "provider": "Microsoft-Windows-WLAN-AutoConfig"
  },
  "settings": {
    "executionTimeLimit": "00:05:00",
    "hidden": false
  },
  "taskNameTemplate": "HomeNetworkAutoLaunch_{FolderName}",
  "descriptionTemplate": "Launches VPN and Outlook when connecting to home Wi-Fi"
}
```

**Run.ps1:**
```powershell
[CmdletBinding()]
param()

# Import helpers
$libPath = Join-Path (Split-Path $PSScriptRoot -Parent) '_lib\TaskHelpers.psm1'
Import-Module $libPath -Force

# Load environment
Import-TaskEnvironment

# Validate config
$validation = Test-RequiredVariables -VariableNames @(
    'HOME_SSID', 'FORTICLIENT_PATH', 'OUTLOOK_PATH'
)
if (-not $validation.IsValid) {
    Write-TaskLog "Missing required variables" -Level Error
    exit 1
}

# Check Wi-Fi connection
if (Test-WifiConnected -SSID $HOME_SSID) {
    Write-TaskLog "Connected to $HOME_SSID" -Level Success
    
    # Wait for network to stabilize
    Wait-NetworkStabilization -Seconds 3
    
    # Launch applications
    Start-ApplicationWithRetry -Path $FORTICLIENT_PATH -Name "FortiClient"
    Start-ApplicationWithRetry -Path $OUTLOOK_PATH -Name "Outlook"
}
else {
    Write-TaskLog "Not connected to home network" -Level Info
}
```

### Example 2: Daily Cleanup

**Purpose:** Clean temp files daily at 2 AM

**task.config.json:**
```json
{
  "trigger": {
    "type": "time",
    "intervalMinutes": 1440
  },
  "settings": {
    "executionTimeLimit": "00:10:00"
  }
}
```

**Run.ps1:**
```powershell
[CmdletBinding()]
param()

Write-Verbose "Starting daily cleanup at $(Get-Date)"

try {
    # Clean temp folder (older than 7 days)
    $tempPath = $env:TEMP
    $deleted = 0
    
    Get-ChildItem $tempPath -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
        ForEach-Object {
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            $deleted++
        }
    
    Write-Host "Deleted $deleted temp files" -ForegroundColor Green
}
catch {
    Write-Error "Cleanup failed: $_"
    exit 1
}
```

### Example 3: Logon Welcome Message

**Purpose:** Show welcome message at user login

**task.config.json:**
```json
{
  "trigger": {
    "type": "logon"
  },
  "settings": {
    "executionTimeLimit": "00:00:30",
    "hidden": false
  }
}
```

**Run.ps1:**
```powershell
[CmdletBinding()]
param()

$user = $env:USERNAME
$time = (Get-Date).ToString("HH:mm")
$day = (Get-Date).ToString("dddd, MMMM dd, yyyy")

Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show(
    "Welcome back, $user!`n`nTime: $time`nDate: $day",
    "Welcome to Windows",
    "OK",
    "Information"
)
```

---

## 🔧 Troubleshooting

### Common Errors

#### Error: "Cannot convert value 'PT5M' to type System.TimeSpan"

**Cause:** Using ISO 8601 format instead of TimeSpan format

**Solution:**
```json
❌ "executionTimeLimit": "PT5M"
✅ "executionTimeLimit": "00:05:00"
```

#### Error: "You cannot call a method on a null-valued expression"

**Cause:** Invalid `userId` or other principal settings

**Solution:** Remove `principal` section from task.config.json (defaults work fine)
```json
❌ Don't do this:
{
  "principal": {
    "userId": "CURRENT_USER"  // Invalid placeholder
  }
}

✅ Remove the entire "principal" section - defaults handle it
```

#### Error: "Access denied" when creating task

**Cause:** Need administrator privileges

**Solution:** Run PowerShell as Administrator
```powershell
# Right-click PowerShell → Run as Administrator
```

### Common Issues

#### Task created but never triggers

**Checklist:**

1. **Verify event log exists**
   ```powershell
   Get-WinEvent -LogName "Your-Log-Name" -MaxEvents 1
   ```

2. **Verify event ID is correct**
   ```powershell
   Get-WinEvent -LogName "Your-Log-Name" |
       Where-Object { $_.Id -eq YourEventId } |
       Select-Object -First 1
   ```

3. **Check provider name**
   ```powershell
   (Get-WinEvent -LogName "Your-Log-Name" -MaxEvents 1).ProviderName
   ```

4. **View task history**
   ```powershell
   Get-ScheduledTaskInfo -TaskName "YourTaskName"
   ```

#### Task shows "Running" but nothing happens

**Cause:** Script has syntax errors or missing dependencies

**Solution:** Test script manually
```powershell
cd "path\to\task\folder"
.\Run.ps1 -Verbose
```

**Check errors:**
```powershell
# Test for syntax errors
pwsh.exe -NoProfile -File ".\Run.ps1" -Verbose
```

#### Task runs but applications don't launch

**Causes:**
- Application path is incorrect
- Application requires user interaction
- Application needs specific environment

**Solutions:**
1. **Verify paths in .env file**
2. **Test with full path:**
   ```powershell
   Start-Process "C:\full\path\to\app.exe"
   ```
3. **Check if app is already running:**
   ```powershell
   Get-Process -Name "appname" -ErrorAction SilentlyContinue
   ```

### Debugging Tips

#### 1. Make task window visible
```json
{
  "settings": {
    "hidden": false
  }
}
```

#### 2. Enable verbose output
```json
{
  "execution": {
    "additionalArguments": "-Verbose"
  }
}
```

#### 3. Test script manually
```powershell
cd "path\to\your\task"
.\Run.ps1 -Verbose
```

#### 4. Check Task Scheduler logs
```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-TaskScheduler/Operational'
    Id = 102  # Task completed
} -MaxEvents 10
```

#### 5. Manually trigger task
```powershell
Start-ScheduledTask -TaskName "YourTaskName"

# Then check status
Get-ScheduledTaskInfo -TaskName "YourTaskName"
```

---

## 📚 Reference

### TaskHelpers Library Functions

Import the library in your Run.ps1:
```powershell
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) '_lib\TaskHelpers.psm1')
```

**Available Functions:**

#### Environment
```powershell
# Load .env file
Import-TaskEnvironment                    # Loads from .env in script folder
Import-TaskEnvironment -Path "custom.env" # Load from custom path
```

#### Logging
```powershell
Write-TaskLog "Message" -Level Info
Write-TaskLog "Success!" -Level Success
Write-TaskLog "Warning" -Level Warning
Write-TaskLog "Error" -Level Error
Write-TaskSeparator                       # Writes ========
Write-TaskSeparator -Character '-' -Length 40
```

#### Application Management
```powershell
# Launch with retry logic
Start-ApplicationWithRetry -Path "C:\app.exe" -Name "MyApp"
Start-ApplicationWithRetry -Path "C:\app.exe" -MaxRetries 5 -RetryDelay 3

# Check if running
Test-ProcessRunning -ProcessName "notepad"
Test-ProcessRunning -Path "C:\path\to\app.exe"
```

#### Configuration Validation
```powershell
# Validate required variables
$result = Test-RequiredVariables -VariableNames @('VAR1', 'VAR2')
if (-not $result.IsValid) {
    Write-TaskLog "Missing: $($result.MissingVariables -join ', ')" -Level Error
}

# Display configuration
Write-ConfigurationSummary -Variables @{
    'Setting 1' = 'Value 1'
    'API Key' = 'secret'
} -MaskSecrets  # Masks keys containing 'password', 'key', 'secret', etc.
```

#### Network Functions
```powershell
# Get Wi-Fi profile
$wifi = Get-WifiConnectionProfile

# Test specific network
if (Test-WifiConnected -SSID "HomeNetwork") {
    Write-Host "Connected to home!"
}

# Wait for network
Wait-NetworkStabilization -Seconds 5
Wait-NetworkStabilization -Seconds 5 -ShowProgress
```

#### Utility Functions
```powershell
# Retry logic
$result = Invoke-WithRetry -ScriptBlock {
    Invoke-RestMethod -Uri "https://api.example.com"
} -MaxRetries 3 -RetryDelay 2 -ErrorMessage "API call failed"
```

### Create.ps1 Parameters

| Parameter | Type | Values | Description |
|-----------|------|--------|-------------|
| `-Action` | String | `Create`, `Remove`, `List`, `Validate` | Action to perform |
| `-FolderName` | String | Folder name | Specific folder to process |
| `-Force` | Switch | | Recreate existing tasks |
| `-WhatIf` | Switch | | Preview changes only |
| `-Verbose` | Switch | | Show detailed output |

**Examples:**
```powershell
# Create all tasks
.\Create.ps1 -Action Create

# Create specific task (verbose)
.\Create.ps1 -Action Create -FolderName "my-task" -Verbose

# Recreate task (force)
.\Create.ps1 -Action Create -FolderName "my-task" -Force

# Preview what would be created
.\Create.ps1 -Action Create -WhatIf

# List all managed tasks
.\Create.ps1 -Action List

# Validate folder structure
.\Create.ps1 -Action Validate

# Remove specific task
.\Create.ps1 -Action Remove -FolderName "my-task"
```

### Best Practices

✅ **DO:**
- Use the `_template` folder as starting point
- Document tasks in README.md
- Test scripts manually before creating tasks
- Use `.env` for configuration
- Use `TaskHelpers` library functions
- Start with `hidden: false` for debugging
- Keep task names descriptive
- Use minimal configuration (only override what's needed)

❌ **DON'T:**
- Hardcode paths or secrets in Run.ps1
- Use ISO 8601 format for `executionTimeLimit`
- Override `principal` unless necessary
- Create tasks without testing first
- Use complex logic in Run.ps1 without error handling

### Skip a Folder

To exclude a folder from task creation, create any of these files:
- `.skip`
- `!skip`
- `skip`

```powershell
# Skip a folder
New-Item "my-task\.skip" -ItemType File

# Un-skip a folder
Remove-Item "my-task\.skip"
```

---

## 📝 Version History

- **v2.0** (Nov 10, 2025) - Consolidated documentation, added TaskHelpers
- **v1.0** (Earlier) - Initial implementation

---

**Last Updated:** November 10, 2025  
**Maintainer:** Task Management System

---

*For questions or issues, refer to the troubleshooting section or test your task manually with `.\Run.ps1 -Verbose`*
