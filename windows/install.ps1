<#
.SYNOPSIS
    Seamless Connect - Windows Automated Installer
.DESCRIPTION
    Installs Google platform-tools (ADB & Fastboot), registers the event-triggered
    Windows Scheduled Task, and sets up File Explorer integration.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SkipAdbDownload
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "         Seamless Connect - Windows Installation            " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$connectScript = Join-Path $scriptDir "scripts\seamless-connect.ps1"
$macScript     = Join-Path $scriptDir "scripts\get-my-mac.ps1"

# 1. Install Google Platform Tools if needed
$adbPath = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source
if (-not $adbPath -and -not $SkipAdbDownload) {
    $installDir = "$env:LOCALAPPDATA\Android\platform-tools"
    if (-not (Test-Path "$installDir\adb.exe")) {
        Write-Host "Installing official Google Android platform-tools..." -ForegroundColor Yellow
        $zipUrl  = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
        $zipDest = "$env:TEMP\platform-tools-latest-windows.zip"
        
        $null = New-Item -ItemType Directory -Path "$env:LOCALAPPDATA\Android" -Force -ErrorAction SilentlyContinue
        curl.exe -L -o $zipDest $zipUrl
        Expand-Archive -Path $zipDest -DestinationPath "$env:LOCALAPPDATA\Android" -Force
        Remove-Item $zipDest -Force
    }

    # Add to User PATH
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notlike "*$installDir*") {
        $newUserPath = if ($userPath) { "$userPath;$installDir" } else { $installDir }
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        Write-Host "Added $installDir to User PATH." -ForegroundColor Green
    }
    $env:Path = "$installDir;$env:Path"
}

# 2. Register Windows Scheduled Task (Event ID 10000 on Network Connected)
Write-Host "Registering automated background trigger..." -ForegroundColor Yellow
$taskName = "SeamlessConnect"

$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Seamless Connect - Wireless ADB and FTP Auto-Connect on Wi-Fi Join</Description>
    <URI>\$taskName</URI>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=10000)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-WindowStyle Hidden -ExecutionPolicy Bypass -File "$connectScript"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

$tempXml = "$env:TEMP\seamless_connect_task.xml"
[System.IO.File]::WriteAllText($tempXml, $taskXml, [System.Text.Encoding]::Unicode)
schtasks.exe /create /tn $taskName /xml $tempXml /f | Out-Null
Remove-Item $tempXml -Force

if ($LASTEXITCODE -eq 0) {
    Write-Host "Automated event task '$taskName' registered successfully!" -ForegroundColor Green
} else {
    Write-Warning "Could not register task via schtasks. You can run scripts\seamless-connect.ps1 manually."
}

# 3. Print Hardware MAC Address
Write-Host ""
if (Test-Path $macScript) {
    & $macScript
}

# 4. Run first connection test
Write-Host "`nRunning initial connection check..." -ForegroundColor Cyan
if (Test-Path $connectScript) {
    & $connectScript
}

Write-Host "`nInstallation Complete! Seamless Connect is now active on Windows." -ForegroundColor Green
