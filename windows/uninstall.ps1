<#
.SYNOPSIS
    Seamless Connect - Windows Automated Uninstaller
.DESCRIPTION
    Removes the event task, File Explorer network locations, and desktop shortcuts.
#>

[CmdletBinding()]
param()

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "         Seamless Connect - Windows Uninstallation          " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Remove Scheduled Task
$taskName = "SeamlessConnect"
Write-Host "Removing scheduled event task '$taskName'..." -ForegroundColor Yellow
schtasks.exe /delete /tn $taskName /f 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Scheduled task removed." -ForegroundColor Green
} else {
    Write-Host "Scheduled task was not found or already removed." -ForegroundColor Gray
}

# 2. Remove Network Location Shortcut
$netHoodDir = [Environment]::GetFolderPath('NetworkShortcuts')
if ([string]::IsNullOrWhiteSpace($netHoodDir)) {
    $netHoodDir = Join-Path $env:APPDATA 'Microsoft\Windows\Network Shortcuts'
}
$netShortcut = Join-Path $netHoodDir "Phone (FTP).url"
if (Test-Path $netShortcut) {
    Remove-Item $netShortcut -Force
    Write-Host "Removed File Explorer network shortcut." -ForegroundColor Green
}

# 3. Remove Desktop Shortcut
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) "Phone (FTP).url"
if (Test-Path $desktopShortcut) {
    Remove-Item $desktopShortcut -Force
    Write-Host "Removed Desktop shortcut." -ForegroundColor Green
}

Write-Host "`nUninstallation Complete." -ForegroundColor Green
