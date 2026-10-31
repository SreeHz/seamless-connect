<#
.SYNOPSIS
    Automated Publisher for Seamless Connect v1.2.1 Release
.DESCRIPTION
    Authenticates with GitHub (using gh CLI or Git Credential Manager), pushes commits and tags,
    and publishes the v1.2.1 GitHub release with all 4 assets.
#>

[CmdletBinding()]
param()

$repoDir = "C:\Users\raswanth\seamless-connect"
Set-Location $repoDir
$env:Path = "$env:LOCALAPPDATA\Programs\GitHubCLI;$env:LOCALAPPDATA\Programs\Git\cmd;$env:LOCALAPPDATA\Android\platform-tools;$env:Path"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       Seamless Connect - Publish v1.2.1 to GitHub          " -ForegroundColor Cyan
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

# 3. Publish GitHub Release v1.2.1
$releaseTitle = "v1.2.1 - Windows Network Location & Wireless FTP Auto-Start Fixes"
$releaseNotes = @'
## What's New in v1.2.1

### Critical Fixes (Windows, Linux & Android)
- **Fixed Wireless FTP Auto-Start Over ADB (Windows & Linux)**: Properly single-quoted the `adb shell su -c` command payload in `seamless-connect.ps1` and `99-seamless-ftp.sh` so Android's `/system/bin/sh` no longer drops quotes and fails on `; then` when launching `seamless-ctl start`.
- **Native Windows File Explorer Network Location (`This PC`)**: Upgraded `update-explorer.ps1` to create a true Windows Shell Folder Shortcut (`CLSID {0AFACED1-E828-11D1-9187-B532F1E9575D}`) inside `Network Shortcuts` with instant `SHChangeNotify` refresh - enabling direct in-place root (`/`) FTP browsing inside File Explorer without browser `UserChoice` (`MSEdgeHTM`) hijacking.
- **Hotspot DHCP Race Protection & Live Port Verification (Windows)**: Added Wi-Fi gateway polling (handling early `EventID=10000` `Identifying...` triggers before DHCP completes), automatic `offline` ADB socket recovery, live TCP port `2121` verification, and run logging (`%LOCALAPPDATA%\SeamlessConnect\seamless-connect.log`).
- **Multi-Interface & Dual-Band SoftAP Firewall Hardening (`ftp-server.sh`)**: Improved interface detection via live `ip neigh` MAC lookup and hardened `iptables` to enforce MAC whitelisting and port `2121` `DROP` across all interfaces (supporting bridged dual-band SoftAP, Wi-Fi STA+AP concurrency, and single-band hotspots alike).

### Native Windows Support (from v1.2.0)
- **Native Event-Triggered Daemon**: Windows Scheduled Task triggered by Event ID `10000` (*Network Profile Connected*) with zero idle CPU/RAM footprint.
- **Official Google Platform-Tools**: Auto-installs official Google Android SDK platform-tools (`adb`, `fastboot`) into user `PATH` with zero admin elevation required.

---

### Release Assets
1. **`SeamlessConnect.apk`**: Native Android companion app with Material Design OLED dark theme and 1-tap MAC authorization.
2. **`seamless_connect_magisk.zip`**: Magisk / KernelSU / APatch root module (`v1.2.1`, POSIX/LF packaged).
3. **`seamless_connect_windows.zip`**: Standalone Windows installation bundle (`install.ps1`, `uninstall.ps1`, and scripts).
4. **`seamless_connect_linux.zip`**: Standalone Linux installation bundle (`install.sh`, dispatchers, and scripts).
'@

$apkAsset = "$repoDir\build\release\SeamlessConnect.apk"
$magiskAsset = "$repoDir\build\release\seamless_connect_magisk.zip"
$winAsset = "$repoDir\build\release\seamless_connect_windows.zip"
$linuxAsset = "$repoDir\build\release\seamless_connect_linux.zip"

$notesFile = "$env:TEMP\seamless_release_notes_v121.md"
[System.IO.File]::WriteAllText($notesFile, $releaseNotes, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "`nPublishing GitHub Release v1.2.1 with all 4 assets..." -ForegroundColor Yellow
gh release create "v1.2.1" `
    "$apkAsset" `
    "$magiskAsset" `
    "$winAsset" `
    "$linuxAsset" `
    --title "$releaseTitle" `
    --notes-file "$notesFile"
$ghExit = $LASTEXITCODE
Remove-Item $notesFile -Force -ErrorAction SilentlyContinue

if ($ghExit -eq 0) {
    Write-Host "`nRelease v1.2.1 published successfully to GitHub!" -ForegroundColor Green
    Write-Host "View release: https://github.com/SreeHz/seamless-connect/releases/tag/v1.2.1" -ForegroundColor Cyan
} else {
    Write-Warning "Could not publish release automatically. You can publish manually from GitHub web."
    exit $ghExit
}
