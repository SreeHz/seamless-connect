<#
.SYNOPSIS
    Updates Windows File Explorer Network Shortcuts with current Phone FTP endpoint.
.DESCRIPTION
    Dynamically registers or updates "Phone (FTP)" under This PC / Network Locations
    and creates a desktop shortcut for one-click browsing.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$PhoneIP,

    [Parameter(Position = 1)]
    [int]$Port = 2121,

    [Parameter()]
    [string]$Username = "phone",

    [Parameter()]
    [string]$Password = "phone"
)

$targetUrl = "ftp://${Username}:${Password}@${PhoneIP}:${Port}/"

# 1. Update Windows Explorer Network Locations (This PC)
$netHoodDir = [Environment]::GetFolderPath('NetworkShortcuts')
if ([string]::IsNullOrWhiteSpace($netHoodDir)) {
    $netHoodDir = Join-Path $env:APPDATA 'Microsoft\Windows\Network Shortcuts'
}

if (-not (Test-Path $netHoodDir)) {
    New-Item -ItemType Directory -Path $netHoodDir -Force | Out-Null
}

$netShortcutPath = Join-Path $netHoodDir "Phone (FTP).url"
$urlContent = @"
[InternetShortcut]
URL=$targetUrl
IconIndex=194
IconFile=C:\Windows\System32\shell32.dll
"@

[System.IO.File]::WriteAllText($netShortcutPath, $urlContent, [System.Text.Encoding]::UTF8)
Write-Verbose "[Explorer] Updated Network Location -> $targetUrl"

# 2. Update Desktop Shortcut for Quick Access
$desktopDir = [Environment]::GetFolderPath('Desktop')
if (Test-Path $desktopDir) {
    $desktopShortcutPath = Join-Path $desktopDir "Phone (FTP).url"
    [System.IO.File]::WriteAllText($desktopShortcutPath, $urlContent, [System.Text.Encoding]::UTF8)
    Write-Verbose "[Explorer] Updated Desktop shortcut -> $targetUrl"
}

Write-Output "Successfully updated File Explorer shortcuts for Phone (FTP) -> $targetUrl"
