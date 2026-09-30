#!/usr/bin/env bash
# get-my-mac.sh — Display Wi-Fi hardware MAC addresses for Seamless Connect
echo "========================================================"
echo " Seamless Connect — Laptop Wi-Fi MAC Address Finder"
echo "========================================================"
echo ""

found=0
for iface in /sys/class/net/*; do
    name=$(basename "$iface")
    if [ -d "$iface/wireless" ] || [[ "$name" =~ ^(wl|wlan|wifi) ]]; then
        mac=$(cat "$iface/address" 2>/dev/null)
        operstate=$(cat "$iface/operstate" 2>/dev/null)
        echo " Interface: $name"
        echo " Status:    $operstate"
        echo " MAC Addr:  $mac"
        echo "--------------------------------------------------------"
        echo "👉 Add this MAC to your Seamless Connect Android App:"
        echo "   $mac"
        echo "--------------------------------------------------------"
        found=1
    fi
done

if [ "$found" -eq 0 ]; then
    echo "No wireless interfaces detected via /sys/class/net/."
    echo "Checking 'ip link'..."
    ip link show | grep -E '^[0-9]+: (wl|wlan)' -A 1
fi
echo ""
