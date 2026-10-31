<#
.SYNOPSIS
    Seamless Connect - Windows Main Connection Orchestrator
.DESCRIPTION
    Auto-connects Wireless ADB, starts the MAC-locked root FTP server on the phone,
    and updates the native File Explorer Network Location upon joining Phone Hotspot or LAN.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TargetPhoneIp,

    [Parameter()]
    [switch]$NoNotification
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $env:LOCALAPPDATA "SeamlessConnect"
$logFile = Join-Path $logDir "seamless-connect.log"

function Write-SeamlessLog {
    param([string]$Message)
    Write-Verbose $Message
    try {
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 262144)) {
            Move-Item -Path $logFile -Destination "$logFile.old" -Force -ErrorAction SilentlyContinue
        }
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $logFile -Value "[$ts] $Message" -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Test-TcpPort {
    param(
        [string]$IP,
        [int]$Port,
        [int]$TimeoutMs = 1000
    )
    if ([string]::IsNullOrWhiteSpace($IP)) { return $false }
    $tcp = $null
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($IP, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($ok -and $tcp.Connected) {
            $tcp.EndConnect($iar)
            return $true
        }
    } catch {} finally {
        if ($tcp) { $tcp.Close() }
    }
    return $false
}

function Get-ActiveWifiInfo {
    $wifiAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
        $_.Status -eq 'Up' -and (
            $_.InterfaceType -eq 71 -or
            $_.Name -match 'Wi-Fi|WLAN|Wireless' -or
            $_.InterfaceDescription -match 'Wi-Fi|WLAN|Wireless|802\.11'
        )
    })

    foreach ($adapter in $wifiAdapters) {
        $gw = Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
              Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
              Select-Object -ExpandProperty NextHop -First 1
        if ($gw) {
            $mac = ($adapter.MacAddress -replace '-', ':').ToLower()
            return [PSCustomObject]@{
                Gateway = $gw
                Mac     = $mac
                Adapter = $adapter.Name
            }
        }
    }

    # Fallback route lookup by InterfaceAlias
    $fallbackGw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                  Where-Object { $_.InterfaceAlias -match 'Wi-Fi|WLAN|Wireless' -and $_.NextHop -ne '0.0.0.0' } |
                  Select-Object -ExpandProperty NextHop -First 1
    if ($fallbackGw) {
        return [PSCustomObject]@{
            Gateway = $fallbackGw
            Mac     = ""
            Adapter = "Wi-Fi"
        }
    }
    return $null
}

Write-SeamlessLog "Triggered Seamless Connect run."

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
    Write-SeamlessLog "ERROR: ADB binary not found."
    Write-Warning "ADB binary not found. Run install.ps1 to download official Google platform-tools."
    exit 1
}

# 2. Detect Active Wi-Fi Default Gateway (wait up to 8s if Event 10000 fired during DHCP 'Identifying...')
$wifiInfo = $null
if (-not $TargetPhoneIp) {
    for ($attempt = 0; $attempt -lt 16; $attempt++) {
        $wifiInfo = Get-ActiveWifiInfo
        if ($wifiInfo -and $wifiInfo.Gateway) { break }
        Start-Sleep -Milliseconds 500
    }
} else {
    $wifiInfo = Get-ActiveWifiInfo
}

$gw = if ($wifiInfo) { $wifiInfo.Gateway } else { $null }
$laptopMac = if ($wifiInfo) { $wifiInfo.Mac } else { "" }

# 3. Resolve Phone IP
$phoneIp = $TargetPhoneIp
if (-not $phoneIp) {
    $discoverScript = Join-Path $scriptDir "seamless-discover.ps1"
    if (Test-Path $discoverScript) {
        $phoneIp = (& $discoverScript -Gateway $gw | Select-Object -Last 1)
        if ($phoneIp) { $phoneIp = "$phoneIp".Trim() }
    }
}

if (-not $phoneIp) {
    Write-SeamlessLog "No Seamless Connect phone found on current network (gw=$gw)."
    exit 0
}

Write-Host "Discovered phone IP: $phoneIp" -ForegroundColor Cyan
Write-SeamlessLog "Discovered phone IP: $phoneIp (gw=$gw, mac=$laptopMac)"

# 4. Connect Wireless ADB
Write-Host "Connecting ADB to ${phoneIp}:5555..."
$connOut = & $adbPath connect "${phoneIp}:5555" 2>&1
Write-SeamlessLog "adb connect output: $connOut"

# Poll to verify device authorization (auto-recover if socket is stale/offline)
$isAuthorized = $false
$escapedIp = [regex]::Escape($phoneIp)
$devices = ""
for ($i = 0; $i -lt 6; $i++) {
    $devices = (& $adbPath devices) -join "`n"
    if ($devices -match "${escapedIp}:5555\s+device\b") {
        $isAuthorized = $true
        break
    }
    if ($devices -match "${escapedIp}:5555\s+offline\b") {
        Write-SeamlessLog "ADB device ${phoneIp}:5555 is offline; reconnecting..."
        & $adbPath disconnect "${phoneIp}:5555" | Out-Null
        Start-Sleep -Milliseconds 400
        & $adbPath connect "${phoneIp}:5555" | Out-Null
    }
    Start-Sleep -Seconds 1
}

# 5. Start Phone-Side Root FTP Server & Update File Explorer Network Location
$ftpReachable = $false
if ($isAuthorized) {
    Write-Host "ADB connection established and authorized." -ForegroundColor Green

    # Pass a single properly quoted command to adb shell so /system/bin/sh forwards the full script intact to su -c
    $remoteCmd = "su -c 'if command -v seamless-ctl >/dev/null 2>&1; then seamless-ctl start; elif [ -x /data/adb/seamless_connect/ftp-server.sh ]; then /data/adb/seamless_connect/ftp-server.sh start; elif [ -x /data/adb/ftp-server.sh ]; then /data/adb/ftp-server.sh start; else echo ERR_NO_FTP_SCRIPT; exit 1; fi'"
    $ftpOut = (& $adbPath -s "${phoneIp}:5555" shell $remoteCmd 2>&1) -join " "
    $ftpExit = $LASTEXITCODE
    Write-SeamlessLog "Phone FTP start (exit=$ftpExit): $ftpOut"

    # Update Windows File Explorer Network Location ("This PC" -> "Phone (FTP)")
    $updateExplorerScript = Join-Path $scriptDir "update-explorer.ps1"
    if (Test-Path $updateExplorerScript) {
        $explorerOut = & $updateExplorerScript -PhoneIP $phoneIp -Port 2121
        Write-SeamlessLog "$explorerOut"
        Write-Host $explorerOut -ForegroundColor Green
    }

    # Verify TCP port 2121 is reachable from this laptop (confirms ftpd is up and laptop MAC is whitelisted)
    for ($p = 0; $p -lt 5; $p++) {
        if (Test-TcpPort -IP $phoneIp -Port 2121 -TimeoutMs 900) {
            $ftpReachable = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }

    if ($ftpReachable) {
        Write-Host "Root FTP server verified reachable at ftp://${phoneIp}:2121/" -ForegroundColor Green
        Write-SeamlessLog "FTP port 2121 verified reachable at ${phoneIp}:2121."
    } else {
        $macHint = if ($laptopMac) { " ($laptopMac)" } else { "" }
        Write-Warning "ADB connected, but FTP port 2121 on $phoneIp did not respond. Ensure this laptop's Wi-Fi MAC$macHint is authorized in Seamless Connect on your phone (and Wi-Fi Random Hardware Addresses is off)."
        Write-SeamlessLog "WARNING: FTP port 2121 unreachable on $phoneIp (laptop MAC: $laptopMac)."
    }
} elseif ($devices -match "${escapedIp}:5555\s+unauthorized\b") {
    Write-SeamlessLog "ADB connected to $phoneIp but unauthorized."
    Write-Warning "Device connected but unauthorized. Please check phone screen and tap 'Always allow from this computer'."
} else {
    Write-SeamlessLog "ADB could not connect to ${phoneIp}:5555. adb devices: $devices"
}

# 6. Show Windows Desktop Notification
if (-not $NoNotification -and ($isAuthorized -or ($devices -match "${escapedIp}:5555\s+unauthorized\b"))) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipTitle = "Seamless Connect"
        if ($isAuthorized -and $ftpReachable) {
            $notify.BalloonTipText = "Connected to Phone ($phoneIp)`nWireless ADB & Phone (FTP) ready in This PC."
        } elseif ($isAuthorized) {
            $macMsg = if ($laptopMac) { " Authorize MAC $laptopMac on phone." } else { " Check MAC authorization on phone." }
            $notify.BalloonTipText = "ADB connected ($phoneIp), but FTP port 2121 is blocked.$macMsg"
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
