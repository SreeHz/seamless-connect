<#
.SYNOPSIS
    Automated Publisher for Seamless Connect v1.2.2 Release
.DESCRIPTION
    Authenticates with GitHub (using gh CLI or Git Credential Manager), pushes commits and tags,
    and publishes the v1.2.2 GitHub release with all 4 assets.
#>

[CmdletBinding()]
param()

$repoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoDir
$env:Path = "$env:LOCALAPPDATA\Programs\GitHubCLI;$env:LOCALAPPDATA\Programs\Git\cmd;$env:LOCALAPPDATA\Android\platform-tools;$env:Path"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       Seamless Connect - Publish v1.2.2 to GitHub          " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Check GitHub Authentication (fallback to Git Credential Manager token in memory)
Write-Host "Checking GitHub authentication status..." -ForegroundColor Yellow
$null = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    $credLines = "protocol=https`nhost=github.com`n`n" | git -C $repoDir credential fill 2>$null
    $tokenLine = $credLines | Where-Object { $_ -match "^password=" } | Select-Object -First 1
    if ($tokenLine) {
        $env:GH_TOKEN = $tokenLine.Substring(9).Trim()
    }
}

$null = gh auth status 2>&1
if ($LASTEXITCODE -ne 0 -and -not $env:GH_TOKEN) {
    Write-Host "Opening browser for 1-click GitHub authentication..." -ForegroundColor Cyan
    gh auth login --web --git-protocol https --scopes "repo,read:org"
} else {
    Write-Host "GitHub authentication verified!" -ForegroundColor Green
}

# 2. Push commits and tags to origin
Write-Host "`nPushing main branch and tags to GitHub..." -ForegroundColor Yellow
git push origin main --tags
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Git push failed. Please check your network connection or permissions."
    exit 1
}
Write-Host "Pushed main branch and tags successfully!" -ForegroundColor Green

# 3. Publish GitHub Release v1.2.2
$releaseTitle = "v1.2.2 - Linux GVFS Zero-Click FTP, Boot User Detection & Multi-Interface State Fix"
$releaseNotes = @'
## What's New in v1.2.2

### Critical Fixes (Linux & Android Daemon)
- **Fixed Multi-Interface Firewall State Clobbering (`ftp-server.sh`)**: Preserved immutable `CFG_IFACE` from `seamless.conf` and isolated `TCPSVD_PID` extraction in a subshell during `teardown` so sourcing `/data/local/tmp/ftp-server.state` no longer overwrites `IFACE="auto"` with a single stale interface (`wlan2`/`wlan0`) on subsequent restarts.
- **Zero-Click Linux GVFS / KDE KIO Anonymous FTP URI**: Updated `update-filemanagers.py` and `99-seamless-ftp.sh` to generate `ftp://anonymous@<ip>:2121/` bookmarks instead of `ftp://phone:phone@<ip>:2121/`, eliminating password prompt dialogs in Nemo, Nautilus, Thunar, and Dolphin when Android Hotspot randomizes its subnet IP.
- **Linux Boot-Time Desktop User Detection**: Hardened `detect_active_user()` in `99-seamless-adb.sh`, `99-seamless-ftp.sh`, and `install.sh` with UID-based `loginctl` filtering and a `getent passwd` (`1000 <= UID < 60000`) fallback so pre-login boot Wi-Fi connections run ADB and bookmark updates as the real desktop user rather than `root`.
- **Stale `offline` Wireless ADB Socket Auto-Recovery (Linux)**: Added automatic `adb disconnect` + `adb connect` recovery in `99-seamless-adb.sh` and `99-seamless-ftp.sh` when `adb devices` reports an `offline` TCP socket, matching Windows behavior.
- **Directed Subnet Broadcast Discovery (Linux)**: Updated `seamless-discover.py` to broadcast `SEAMLESS_DISCOVER` to the `/24` directed subnet broadcast address alongside `255.255.255.255`.

---

### Release Assets
1. **`SeamlessConnect.apk`**: Native Android companion app (`v1.2.2`) with Material Design OLED dark theme and 1-tap MAC authorization.
2. **`seamless_connect_magisk.zip`**: Magisk / KernelSU / APatch root module (`v1.2.2`, POSIX/LF packaged).
3. **`seamless_connect_windows.zip`**: Standalone Windows installation bundle (`install.ps1`, `uninstall.ps1`, and scripts).
4. **`seamless_connect_linux.zip`**: Standalone Linux installation bundle (`install.sh`, dispatchers, and scripts).
'@

$apkAsset = Join-Path $repoDir "build\release\SeamlessConnect.apk"
$magiskAsset = Join-Path $repoDir "build\release\seamless_connect_magisk.zip"
$winAsset = Join-Path $repoDir "build\release\seamless_connect_windows.zip"
$linuxAsset = Join-Path $repoDir "build\release\seamless_connect_linux.zip"

$notesFile = Join-Path $env:TEMP "seamless_release_notes_v122.md"
[System.IO.File]::WriteAllText($notesFile, $releaseNotes, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "`nPublishing GitHub Release v1.2.2 with all 4 assets..." -ForegroundColor Yellow
gh release create "v1.2.2" `
    "$apkAsset" `
    "$magiskAsset" `
    "$winAsset" `
    "$linuxAsset" `
    --title "$releaseTitle" `
    --notes-file "$notesFile"
$ghExit = $LASTEXITCODE
Remove-Item $notesFile -Force -ErrorAction SilentlyContinue

if ($ghExit -eq 0) {
    Write-Host "`nRelease v1.2.2 published successfully to GitHub!" -ForegroundColor Green
    Write-Host "View release: https://github.com/SreeHz/seamless-connect/releases/tag/v1.2.2" -ForegroundColor Cyan
} else {
    Write-Warning "Could not publish release automatically. You can publish manually from GitHub web."
    exit $ghExit
}
