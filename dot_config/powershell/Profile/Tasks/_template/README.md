# Task Name

## Description

Brief description of what this task does.

## Purpose

Explain why this task exists and what problem it solves.

## Trigger

Describe when this task runs:
- **Type:** Event/Time/Logon/Startup
- **Details:** Specific event ID, interval, etc.

## Configuration

### Environment Variables (.env)

If using `.env` file, document the required variables:

```
VARIABLE_NAME=description of what this does
ANOTHER_VAR=example value
```

### Task Configuration (task.config.json)

If using custom task configuration, explain the settings:

```json
{
  "trigger": {
    "type": "event",
    "eventLog": "Application",
    "eventId": 1000
  }
}
```

## Requirements

- PowerShell 7+
- Administrator privileges (if needed)
- Any required modules or external tools

## How It Works

Detailed explanation of the task's workflow:

1. Step one happens
2. Then step two
3. Finally step three

## Manual Testing

How to test this task manually:

```powershell
# Navigate to task folder
cd "$env:PSProfileDir\Profile\Tasks\task-name"

# Run the script
.\Run.ps1 -Verbose
```

## Troubleshooting

Common issues and solutions:

### Issue 1
**Problem:** Description of problem

**Solution:** How to fix it

### Issue 2
**Problem:** Another issue

**Solution:** Another fix

## Logs

Where to find logs for this task:

```powershell
# View Task Scheduler logs
Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' |
    Where-Object { $_.Message -like '*ProfileTask_task-name*' }
```

## Notes

Any additional important information.

## Related

- Links to related documentation
- Related tasks
- External references
