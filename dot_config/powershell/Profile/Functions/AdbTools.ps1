function Get-AdbDevices {
    <#
    .SYNOPSIS
        Retrieves a list of connected Android devices/emulators using adb.

    .DESCRIPTION
        This function runs `adb devices -l` and returns an array of device IDs.
        It filters out the header line and only includes valid device identifiers.

    .OUTPUTS
        [string[]] List of device IDs.

    .EXAMPLE
        Get-AdbDevices
    #>
    try {
        $devices = adb devices -l 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to execute adb. Ensure adb is installed and in PATH.'
        }

        $deviceList = $devices | Select-Object -Skip 1 | ForEach-Object {
            if ($_ -match '^(emulator-\d+|[\w\d]+)\s+device') {
                ($_ -split '\s+')[0]
            }
        }

        if (-not $deviceList) {
            Write-Warning 'No connected devices found.'
        }

        return $deviceList
    }
    catch {
        Write-Error "Error retrieving devices: $_"
        return @()
    }
}

function Install-APK {
    <#
    .SYNOPSIS
        Installs an Android APK on one, all, or a specified device.

    .DESCRIPTION
        Wraps `adb install` and adds:
        - `-All` flag to install on all connected devices.
        - `-DeviceId` to install on a specific device.
        If neither is specified, installs on the default device.

    .PARAMETER ApkPath
        The full path to the APK file to install.

    .PARAMETER All
        Switch to install on all connected devices.

    .PARAMETER DeviceId
        Specify a single device ID to install on.

    .EXAMPLE
        Install-APK "C:\path\to\app.apk"
        # Installs on the default device.

    .EXAMPLE
        Install-APK "C:\path\to\app.apk" --All
        # Installs on all connected devices.

    .EXAMPLE
        Install-APK "C:\path\to\app.apk" -DeviceId emulator-5554
        # Installs only on emulator-5554.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$ApkPath,

        [switch]$All,

        [string]$DeviceId
    )

    try {
        if ($All -and $DeviceId) {
            throw 'Cannot use -All and -DeviceId together. Choose one.'
        }

        if ($All) {
            $devices = Get-AdbDevices
            if (-not $devices) {
                throw 'No devices found to install on.'
            }

            $total = $devices.Count
            $index = 0

            foreach ($device in $devices) {
                $index++
                Write-Progress -Activity 'Installing APK' -Status "Device: $device" -PercentComplete (($index / $total) * 100)
                Write-Host "Installing $ApkPath on $device..."
                $result = adb -s $device install $ApkPath 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Success on $device"
                }
                else {
                    Write-Warning "Failed on ${device}: $result"
                }
            }
            Write-Progress -Activity 'Installing APK' -Completed
        }
        elseif ($DeviceId) {
            Write-Host "Installing $ApkPath on $DeviceId..."
            $result = adb -s $DeviceId install $ApkPath 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Success on $DeviceId"
            }
            else {
                Write-Warning "Failed on ${DeviceId}: $result"
            }
        }
        else {
            Write-Host "Installing $ApkPath on default device..."
            $result = adb install $ApkPath 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host 'Success'
            }
            else {
                Write-Warning "Failed: $result"
            }
        }
    }
    catch {
        Write-Error "Error during install: $_"
    }
}
Set-Alias -Name adb-install -Value Install-APK -Force -Description 'Installs an APK on Android devices using adb.'

function Uninstall-APK {
    <#
    .SYNOPSIS
        Uninstalls an Android app from one, all, or a specified device.

    .DESCRIPTION
        Wraps `adb uninstall` and adds:
        - `-All` flag to uninstall from all connected devices.
        - `-DeviceId` to uninstall from a specific device.
        If neither is specified, uninstalls from the default device.

    .PARAMETER PackageName
        The package name of the app to uninstall (e.g., com.example.myapp).

    .PARAMETER All
        Switch to uninstall from all connected devices.

    .PARAMETER DeviceId
        Specify a single device ID to uninstall from.

    .EXAMPLE
        Uninstall-APK "com.example.myapp"
        # Uninstalls from the default device.

    .EXAMPLE
        Uninstall-APK "com.example.myapp" --All
        # Uninstalls from all connected devices.

    .EXAMPLE
        Uninstall-APK "com.example.myapp" -DeviceId emulator-5554
        # Uninstalls only from emulator-5554.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [switch]$All,

        [string]$DeviceId
    )

    try {
        if ($All -and $DeviceId) {
            throw 'Cannot use -All and -DeviceId together. Choose one.'
        }

        if ($All) {
            $devices = Get-AdbDevices
            if (-not $devices) {
                throw 'No devices found to uninstall from.'
            }

            $total = $devices.Count
            $index = 0

            foreach ($device in $devices) {
                $index++
                Write-Progress -Activity 'Uninstalling APK' -Status "Device: $device" -PercentComplete (($index / $total) * 100)
                Write-Host "Uninstalling $PackageName from $device..."
                $result = adb -s $device uninstall $PackageName 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Success on $device"
                }
                else {
                    Write-Warning "Failed on ${device}: $result"
                }
            }
            Write-Progress -Activity 'Uninstalling APK' -Completed
        }
        elseif ($DeviceId) {
            Write-Host "Uninstalling $PackageName from $DeviceId..."
            $result = adb -s $DeviceId uninstall $PackageName 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Success on $DeviceId"
            }
            else {
                Write-Warning "Failed on ${DeviceId}: $result"
            }
        }
        else {
            Write-Host "Uninstalling $PackageName from default device..."
            $result = adb uninstall $PackageName 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host 'Success'
            }
            else {
                Write-Warning "Failed: $result"
            }
        }
    }
    catch {
        Write-Error "Error during uninstall: $_"
    }
}
Set-Alias -Name adb-uninstall -Value Uninstall-APK -Force -Description 'Uninstalls an APK from Android devices using adb.'