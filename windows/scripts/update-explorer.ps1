<#
.SYNOPSIS
    Updates Windows File Explorer Network Locations with current Phone FTP endpoint.
.DESCRIPTION
    Creates/updates a native Windows Shell Folder Shortcut (CLSID {0AFACED1-E828-11D1-9187-B532F1E9575D})
    under Network Shortcuts ("This PC" -> "Network locations") for direct in-place root FTP browsing
    in File Explorer, completely immune to browser URL protocol hijacking.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$PhoneIP,

    [Parameter(Position = 1)]
    [int]$Port = 2121,

    [Parameter()]
    [string]$Username = "",

    [Parameter()]
    [string]$Password = ""
)

if (-not [string]::IsNullOrWhiteSpace($Username)) {
    $credPart = if (-not [string]::IsNullOrWhiteSpace($Password)) { "${Username}:${Password}@" } else { "${Username}@" }
    $targetUrl = "ftp://${credPart}${PhoneIP}:${Port}/"
} else {
    $targetUrl = "ftp://${PhoneIP}:${Port}/"
}

# 1. Ensure native Windows Explorer FTP folder view settings & clean up broken HKCU URL override
try {
    $hkcuFtpClass = "HKCU:\Software\Classes\ftp"
    if (Test-Path $hkcuFtpClass) {
        $shellFolderProp = (Get-ItemProperty -Path $hkcuFtpClass -Name "ShellFolder" -ErrorAction SilentlyContinue).ShellFolder
        if (-not $shellFolderProp) {
            Remove-Item -Path $hkcuFtpClass -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $ieFtpKey = "HKCU:\Software\Microsoft\Ftp"
    if (-not (Test-Path $ieFtpKey)) { New-Item -Path $ieFtpKey -Force | Out-Null }
    Set-ItemProperty -Path $ieFtpKey -Name "Use PASV" -Value "yes" -Force
    Set-ItemProperty -Path $ieFtpKey -Name "Use Web Based FTP" -Value "no" -Force
} catch {
    Write-Verbose "Could not update HKCU FTP preferences: $($_.Exception.Message)"
}

$wsh = New-Object -ComObject WScript.Shell
$sysRoot = if ($env:SystemRoot) { $env:SystemRoot } else { "C:\Windows" }
$iconDll = Join-Path $sysRoot "System32\shell32.dll"
$iconPath = "$iconDll,194"

# 2. Create/Update Native Windows Network Location (Folder Shortcut) in Network Shortcuts ("This PC")
$netHoodDir = [Environment]::GetFolderPath('NetworkShortcuts')
if ([string]::IsNullOrWhiteSpace($netHoodDir)) {
    $netHoodDir = Join-Path $env:APPDATA 'Microsoft\Windows\Network Shortcuts'
}
if (-not (Test-Path $netHoodDir)) {
    New-Item -ItemType Directory -Path $netHoodDir -Force | Out-Null
}

# Remove legacy non-folder shortcuts in Network Shortcuts
Remove-Item (Join-Path $netHoodDir "Phone (FTP).lnk") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $netHoodDir "Phone (FTP).url") -Force -ErrorAction SilentlyContinue

$netLocationDir = Join-Path $netHoodDir "Phone (FTP)"
$desktopIniPath = Join-Path $netLocationDir "desktop.ini"
$targetLnkPath  = Join-Path $netLocationDir "target.lnk"

if (Test-Path $netLocationDir) {
    & attrib.exe -R -S -H "$netLocationDir" | Out-Null
} else {
    New-Item -ItemType Directory -Path $netLocationDir -Force | Out-Null
}

if (Test-Path $desktopIniPath) {
    & attrib.exe -R -S -H "$desktopIniPath" | Out-Null
}
if (Test-Path $targetLnkPath) {
    & attrib.exe -R -S -H "$targetLnkPath" | Out-Null
}

$desktopIniContent = @"
[.ShellClassInfo]
CLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}
Flags=2
IconResource=$iconPath
IconFile=$iconDll
IconIndex=194
"@
[System.IO.File]::WriteAllText($desktopIniPath, $desktopIniContent, [System.Text.Encoding]::Unicode)
& attrib.exe +S +H "$desktopIniPath" | Out-Null

$targetLink = $wsh.CreateShortcut($targetLnkPath)
$targetLink.TargetPath = $targetUrl
$targetLink.IconLocation = $iconPath
$targetLink.Description = "Seamless Connect - Android Phone Root Storage (FTP)"
$targetLink.Save()

# ReadOnly attribute on the folder tells Windows Shell to activate desktop.ini CLSID2 (Folder Shortcut)
& attrib.exe +R "$netLocationDir" | Out-Null

# 3. Create/Update Desktop Shortcut pointing to the Network Location Folder Shortcut path
$desktopDir = [Environment]::GetFolderPath('Desktop')
if (Test-Path $desktopDir) {
    Remove-Item (Join-Path $desktopDir "Phone (FTP).url") -Force -ErrorAction SilentlyContinue

    $desktopShortcutPath = Join-Path $desktopDir "Phone (FTP).lnk"
    $deskLink = $wsh.CreateShortcut($desktopShortcutPath)
    $deskLink.TargetPath = Join-Path $sysRoot "explorer.exe"
    $deskLink.Arguments = "`"$netLocationDir`""
    $deskLink.IconLocation = $iconPath
    $deskLink.Description = "Seamless Connect - Android Phone Root Storage (FTP)"
    $deskLink.Save()
}

# 4. Notify Windows Shell so open "This PC" File Explorer windows refresh immediately
try {
    if (-not ("SeamlessShellNotify" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SeamlessShellNotify {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern void SHChangeNotify(int wEventId, uint uFlags, string dwItem1, string dwItem2);
}
"@ -ErrorAction SilentlyContinue
    }
    # SHCNE_UPDATEDIR = 0x00001000, SHCNF_PATHW = 0x0005, SHCNF_FLUSHNOWAIT = 0x2000
    [SeamlessShellNotify]::SHChangeNotify(0x00001000, 0x2005, $netLocationDir, $null)
    [SeamlessShellNotify]::SHChangeNotify(0x00001000, 0x2005, $netHoodDir, $null)
} catch {
    Write-Verbose "SHChangeNotify skipped: $($_.Exception.Message)"
}

Write-Output "Successfully updated File Explorer Network Location 'Phone (FTP)' -> $targetUrl"
