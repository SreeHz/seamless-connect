#!/usr/bin/env bash
# uninstall.sh — Uninstaller for Seamless Connect Linux Client
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)."
    exit 1
fi

echo "Removing Seamless Connect Linux components..."
rm -f /usr/local/bin/seamless-update-places
rm -f /etc/NetworkManager/dispatcher.d/99-seamless-adb.sh
rm -f /etc/NetworkManager/dispatcher.d/99-zz-seamless-ftp.sh

systemctl restart NetworkManager 2>/dev/null || true
echo "Seamless Connect Linux Client uninstalled successfully."
