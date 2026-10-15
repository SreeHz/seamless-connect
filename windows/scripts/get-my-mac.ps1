<#
.SYNOPSIS
    Displays the laptop's Wi-Fi and Ethernet hardware MAC addresses for Seamless Connect.
.DESCRIPTION
    Formats MAC addresses for easy entry into the Seamless Connect companion app or seamless-ctl.
#>

[CmdletBinding()]
param()

$adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.MacAddress) }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "         Seamless Connect - Hardware MAC Address            " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Enter one of these MAC addresses into the Seamless Connect app"
Write-Host "on your phone, or run: su -c `"seamless-ctl add-mac <MAC> Laptop`"`n"

foreach ($adapter in $adapters) {
    $colonMac = ($adapter.MacAddress -replace '-', ':').ToLower()
    $dashMac  = $adapter.MacAddress.ToUpper()
    
    $statusColor = if ($adapter.Status -eq 'Up') { 'Green' } else { 'Yellow' }
    
    Write-Host "Adapter:     " -NoNewline
    Write-Host "$($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor White
    Write-Host "Status:      " -NoNewline
    Write-Host "$($adapter.Status)" -ForegroundColor $statusColor
    Write-Host "MAC (colon): " -NoNewline
    Write-Host "$colonMac" -ForegroundColor Yellow -NoNewline
    Write-Host "  <-- Recommended for Seamless Connect" -ForegroundColor Gray
    Write-Host "MAC (dash):  $dashMac" -ForegroundColor Gray
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
}
