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

# 2. Remove Network Location Folder Shortcut & Legacy Shortcuts
$netHoodDir = [Environment]::GetFolderPath('NetworkShortcuts')
if ([string]::IsNullOrWhiteSpace($netHoodDir)) {
    $netHoodDir = Join-Path $env:APPDATA 'Microsoft\Windows\Network Shortcuts'
}

$netLocationDir = Join-Path $netHoodDir "Phone (FTP)"
if (Test-Path $netLocationDir) {
    & attrib.exe -R -S -H "$netLocationDir" 2>$null | Out-Null
    $iniPath = Join-Path $netLocationDir "desktop.ini"
    if (Test-Path $iniPath) { & attrib.exe -R -S -H "$iniPath" 2>$null | Out-Null }
    Remove-Item $netLocationDir -Recurse -Force -ErrorAction SilentlyContinue
}
Remove-Item (Join-Path $netHoodDir "Phone (FTP).lnk") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $netHoodDir "Phone (FTP).url") -Force -ErrorAction SilentlyContinue
Write-Host "Removed File Explorer network location." -ForegroundColor Green

# 3. Remove Desktop Shortcuts
$desktopDir = [Environment]::GetFolderPath('Desktop')
Remove-Item (Join-Path $desktopDir "Phone (FTP).lnk") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $desktopDir "Phone (FTP).url") -Force -ErrorAction SilentlyContinue
Write-Host "Removed Desktop shortcuts." -ForegroundColor Green

# 4. Clean up legacy HKCU FTP override if present
$hkcuFtpClass = "HKCU:\Software\Classes\ftp"
if (Test-Path $hkcuFtpClass) {
    $shellFolderProp = (Get-ItemProperty -Path $hkcuFtpClass -Name "ShellFolder" -ErrorAction SilentlyContinue).ShellFolder
    if (-not $shellFolderProp) {
        Remove-Item -Path $hkcuFtpClass -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nUninstallation Complete." -ForegroundColor Green
