<#
.SYNOPSIS
    Network Auto-Discovery for Seamless Connect on Windows.
.DESCRIPTION
    Finds the phone IP whether connected to the phone's Mobile Hotspot or to a shared Wi-Fi/LAN router.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Gateway,

    [Parameter()]
    [int]$TimeoutMs = 1500
)

function Test-AdbPort {
    param(
        [string]$IP,
        [int]$Port = 5555,
        [int]$Timeout = 800
    )
    if ([string]::IsNullOrWhiteSpace($IP)) { return $false }
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($IP, $Port, $null, $null)
        $success = $iar.AsyncWaitHandle.WaitOne($Timeout, $false)
        if ($success -and $tcp.Connected) {
            $tcp.EndConnect($iar)
            $tcp.Close()
            return $true
        }
        $tcp.Close()
    } catch {}
    return $false
}

function Discover-UdpBeacon {
    param(
        [int]$Timeout = 2000
    )
    $udp = $null
    try {
        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.EnableBroadcast = $true
        $udp.Client.ReceiveTimeout = $Timeout

        $broadcastEp = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Broadcast, 21210)
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("SEAMLESS_DISCOVER")
        
        # Send broadcast to 255.255.255.255
        [void]$udp.Send($bytes, $bytes.Length, $broadcastEp)

        # Receive offer
        $remoteEp = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $respBytes = $udp.Receive([ref]$remoteEp)
        $msg = [System.Text.Encoding]::ASCII.GetString($respBytes).Trim()
        
        if ($msg.StartsWith("SEAMLESS_OFFER")) {
            $parts = $msg.Split(":")
            if ($parts.Length -gt 1 -and $parts[1] -ne "Unavailable" -and -not [string]::IsNullOrWhiteSpace($parts[1])) {
                return $parts[1].Trim()
            }
            return $remoteEp.Address.ToString()
        }
    } catch {
        # Timeout or socket error
    } finally {
        if ($udp) { $udp.Close() }
    }
    return $null
}

# 1. Hotspot Fast-Path: If Gateway has ADB port 5555 open, the phone is the hotspot gateway
if ($Gateway -and (Test-AdbPort -IP $Gateway -Port 5555)) {
    Write-Output $Gateway
    exit 0
}

# 2. Shared Wi-Fi / LAN Path: Broadcast discovery beacon to find phone IP
$discoveredIp = Discover-UdpBeacon -Timeout $TimeoutMs
if ($discoveredIp) {
    Write-Output $discoveredIp
    exit 0
}

# 3. Fallback: If gateway was provided, return it as last resort
if ($Gateway) {
    Write-Output $Gateway
    exit 0
}

exit 1
