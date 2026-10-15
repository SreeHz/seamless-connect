<#
.SYNOPSIS
    Updates Windows File Explorer Network Shortcuts with current Phone FTP endpoint.
.DESCRIPTION
    Dynamically registers the FTP protocol association in user registry and creates
    robust Windows Shell (.lnk) shortcuts targeting explorer.exe with the native phone icon.
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

# 1. Register FTP URL protocol association in HKCU (No admin required)
try {
    $ftpKey = "HKCU:\Software\Classes\ftp"
    if (-not (Test-Path $ftpKey)) { New-Item -Path $ftpKey -Force | Out-Null }
    Set-ItemProperty -Path $ftpKey -Name "(Default)" -Value "URL:File Transfer Protocol" -Force
    Set-ItemProperty -Path $ftpKey -Name "URL Protocol" -Value "" -Force

    $cmdKey = "HKCU:\Software\Classes\ftp\shell\open\command"
    if (-not (Test-Path $cmdKey)) { New-Item -Path $cmdKey -Force | Out-Null }
    Set-ItemProperty -Path $cmdKey -Name "(Default)" -Value 'explorer.exe "%1"' -Force
} catch {
    Write-Verbose "Could not update HKCU FTP association: $($_.Exception.Message)"
}

# 2. Create/Update Robust Windows Shell (.lnk) Shortcuts
$wsh = New-Object -ComObject WScript.Shell
$iconPath = "$env:SystemRoot\System32\shell32.dll,194"

# A. Windows Explorer Network Locations (This PC / Network Shortcuts)
$netHoodDir = [Environment]::GetFolderPath('NetworkShortcuts')
if ([string]::IsNullOrWhiteSpace($netHoodDir)) {
    $netHoodDir = Join-Path $env:APPDATA 'Microsoft\Windows\Network Shortcuts'
}
if (-not (Test-Path $netHoodDir)) {
    New-Item -ItemType Directory -Path $netHoodDir -Force | Out-Null
}

$netShortcutPath = Join-Path $netHoodDir "Phone (FTP).lnk"
$netLink = $wsh.CreateShortcut($netShortcutPath)
$netLink.TargetPath = "explorer.exe"
$netLink.Arguments = $targetUrl
$netLink.IconLocation = $iconPath
$netLink.Description = "Seamless Connect - Android Phone Storage (FTP)"
$netLink.Save()

# Remove legacy .url if present
Remove-Item (Join-Path $netHoodDir "Phone (FTP).url") -Force -ErrorAction SilentlyContinue

# B. Desktop Shortcut for Quick Access
$desktopDir = [Environment]::GetFolderPath('Desktop')
if (Test-Path $desktopDir) {
    $desktopShortcutPath = Join-Path $desktopDir "Phone (FTP).lnk"
    $deskLink = $wsh.CreateShortcut($desktopShortcutPath)
    $deskLink.TargetPath = "explorer.exe"
    $deskLink.Arguments = $targetUrl
    $deskLink.IconLocation = $iconPath
    $deskLink.Description = "Seamless Connect - Android Phone Storage (FTP)"
    $deskLink.Save()

    # Remove legacy .url if present
    Remove-Item (Join-Path $desktopDir "Phone (FTP).url") -Force -ErrorAction SilentlyContinue
}

Write-Output "Successfully updated File Explorer shortcuts for Phone (FTP) -> $targetUrl"
