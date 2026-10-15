<#
.SYNOPSIS
    Seamless Connect - Windows Main Connection Orchestrator
.DESCRIPTION
    Auto-connects Wireless ADB and starts root FTP server upon joining Phone Hotspot or LAN.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TargetPhoneIp,

    [Parameter()]
    [switch]$NoNotification
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. Resolve ADB Binary Path
$adbPath = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source
if (-not $adbPath) {
    $fallbackPaths = @(
        "$env:LOCALAPPDATA\Android\platform-tools\adb.exe",
        "$env:ProgramFiles\Android\platform-tools\adb.exe",
        "C:\platform-tools\adb.exe"
    )
    foreach ($p in $fallbackPaths) {
        if (Test-Path $p) {
            $adbPath = $p
            $env:Path = (Split-Path -Parent $p) + ";$env:Path"
            break
        }
    }
}

if (-not $adbPath -or -not (Test-Path $adbPath)) {
    Write-Warning "ADB binary not found. Run install.ps1 to download official Google platform-tools."
    exit 1
}

# 2. Detect Active Wi-Fi Default Gateway
$gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
       Where-Object { $_.InterfaceAlias -match 'Wi-Fi|WLAN|Wireless' } |
       Select-Object -ExpandProperty NextHop -First 1)

# 3. Resolve Phone IP
$phoneIp = $TargetPhoneIp
if (-not $phoneIp) {
    $discoverScript = Join-Path $scriptDir "seamless-discover.ps1"
    if (Test-Path $discoverScript) {
        $phoneIp = & $discoverScript -Gateway $gw
    }
}

if (-not $phoneIp) {
    Write-Verbose "No Seamless Connect phone found on local network."
    exit 0
}

Write-Host "Discovered phone IP: $phoneIp" -ForegroundColor Cyan

# 4. Connect ADB
Write-Host "Connecting ADB to ${phoneIp}:5555..."
& $adbPath connect "${phoneIp}:5555" | Out-Null

# Poll briefly to verify device authorization
$isAuthorized = $false
for ($i = 0; $i -lt 5; $i++) {
    $devices = & $adbPath devices
    if ($devices -match "${phoneIp}:5555\s+device") {
        $isAuthorized = $true
        break
    }
    Start-Sleep -Seconds 1
}

# 5. Start Phone-Side FTP Server & Update Explorer
$ftpStarted = $false
if ($isAuthorized) {
    Write-Host "ADB connection established and authorized." -ForegroundColor Green
    
    # Trigger root FTP daemon on Android device
    $ftpCmd = "if which seamless-ctl >/dev/null 2>&1; then seamless-ctl start; elif [ -x /data/adb/seamless_connect/ftp-server.sh ]; then /data/adb/seamless_connect/ftp-server.sh start; elif [ -x /data/adb/ftp-server.sh ]; then /data/adb/ftp-server.sh start; fi"
    $ftpOut = & $adbPath -s "${phoneIp}:5555" shell su -c "$ftpCmd" 2>&1
    Write-Verbose "Phone FTP server output: $ftpOut"
    $ftpStarted = $true

    # Update Windows File Explorer Network Shortcuts
    $updateExplorerScript = Join-Path $scriptDir "update-explorer.ps1"
    if (Test-Path $updateExplorerScript) {
        & $updateExplorerScript -PhoneIP $phoneIp -Port 2121
    }
} elseif ($devices -match "${phoneIp}:5555\s+unauthorized") {
    Write-Warning "Device connected but unauthorized. Please check phone screen and tap 'Always allow from this computer'."
}

# 6. Show Windows Desktop Notification
if (-not $NoNotification) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipTitle = "Seamless Connect"
        if ($isAuthorized) {
            $notify.BalloonTipText = "Connected to Phone ($phoneIp)`nWireless ADB & Phone (FTP) ready in File Explorer."
        } else {
            $notify.BalloonTipText = "Found Phone ($phoneIp). Tap 'Allow USB Debugging' on your phone to authorize."
        }
        $notify.Visible = $true
        $notify.ShowBalloonTip(4000)
        Start-Sleep -Milliseconds 500
        $notify.Dispose()
    } catch {}
}

exit 0
