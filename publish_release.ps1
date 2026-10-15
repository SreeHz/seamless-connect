<#
.SYNOPSIS
    Automated Publisher for Seamless Connect v1.2.0 Release
.DESCRIPTION
    Authenticates with GitHub via browser, pushes commits and tags,
    and publishes the v1.2.0 GitHub release with all 4 assets.
#>

[CmdletBinding()]
param()

$repoDir = "C:\Users\raswanth\seamless-connect"
Set-Location $repoDir
$env:Path = "$env:LOCALAPPDATA\Programs\GitHubCLI;$env:LOCALAPPDATA\Programs\Git\cmd;$env:LOCALAPPDATA\Android\platform-tools;$env:Path"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       Seamless Connect - Publish v1.2.0 to GitHub          " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Check GitHub Authentication
Write-Host "Checking GitHub authentication status..." -ForegroundColor Yellow
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
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

# 3. Publish GitHub Release v1.2.0
$releaseTitle = "v1.2.0 - Added Windows Compatibility"
$releaseNotes = @"
## 🚀 What's New in v1.2.0

### 💻 Native Windows Support
- **Full Windows Continuity**: Reconnects Wireless ADB and root FTP server seamlessly when your laptop connects to your Android phone's hotspot.
- **Native Event-Triggered Daemon**: Registered as a native Windows Scheduled Task triggered by Event ID ``10000`` (*Network Profile Connected*). Zero CPU/RAM idle footprint.
- **File Explorer (This PC) Integration**: Automatically mounts and pins **Phone (FTP)** with a native mobile device icon (``shell32.dll,194``) under *This PC* and on your Desktop for direct browsing in Windows File Explorer without third-party FTP clients.
- **Official Google Platform-Tools**: Auto-installs pristine Google Android SDK platform-tools (``adb``, ``fastboot``) into user environment.
- **Zero Admin Rights**: Fully operable within standard user privileges.

---

### 📦 Release Assets
1. **``SeamlessConnect.apk``**: Native Android companion app with Material Design OLED dark theme and 1-tap MAC authorization.
2. **``seamless_connect_magisk.zip``**: Magisk / KernelSU / APatch root module (updated to v1.2.0).
3. **``seamless_connect_windows.zip``**: Standalone Windows installation bundle (includes ``install.ps1`` and scripts).
4. **``seamless_connect_linux.zip``**: Standalone Linux installation bundle (includes ``install.sh``, dispatchers, and scripts).
"@

$apkAsset = "$repoDir\build\release\SeamlessConnect.apk"
$magiskAsset = "$repoDir\build\release\seamless_connect_magisk.zip"
$winAsset = "$repoDir\build\release\seamless_connect_windows.zip"
$linuxAsset = "$repoDir\build\release\seamless_connect_linux.zip"

Write-Host "`nPublishing GitHub Release v1.2.0 with all 4 assets..." -ForegroundColor Yellow
gh release create "v1.2.0" `
    "$apkAsset" `
    "$magiskAsset" `
    "$winAsset" `
    "$linuxAsset" `
    --title "$releaseTitle" `
    --notes "$releaseNotes"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n🎉 Release v1.2.0 published successfully to GitHub!" -ForegroundColor Green
    Write-Host "View release: https://github.com/SreeHz/seamless-connect/releases/tag/v1.2.0" -ForegroundColor Cyan
} else {
    Write-Warning "Could not publish release automatically. You can publish manually from GitHub web."
}
