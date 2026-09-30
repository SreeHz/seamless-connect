#!/usr/bin/env bash
# install.sh — Installer for Seamless Connect Linux Client
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE}   Seamless Connect — Linux Client Installer           ${NC}"
echo -e "${BLUE}========================================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo).${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check ADB
if ! command -v adb >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: 'adb' command not found in PATH.${NC}"
    echo "Please ensure Android platform-tools (adb) is installed."
fi

# Detect desktop user
REAL_USER="${SUDO_USER:-$(loginctl list-users --no-legend 2>/dev/null | awk '$1 >= 1000 {print $2; exit}')}"
if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
    REAL_USER=$(who | awk '$2 ~ /(:0|tty2|wayland)/ {print $1; exit}')
fi
REAL_HOME=$(eval echo "~$REAL_USER")

echo -e "Target Desktop User: ${GREEN}$REAL_USER${NC} ($REAL_HOME)"

# 1. Install helper scripts to /usr/local/bin
echo -e "--> Installing file manager places updater to /usr/local/bin/seamless-update-places..."
install -m 755 "$SCRIPT_DIR/scripts/update-filemanagers.py" /usr/local/bin/seamless-update-places
echo -e "--> Installing network discovery helper to /usr/local/bin/seamless-discover..."
install -m 755 "$SCRIPT_DIR/scripts/seamless-discover.py" /usr/local/bin/seamless-discover

# 2. Install NetworkManager dispatchers
DISPATCHER_DIR="/etc/NetworkManager/dispatcher.d"
mkdir -p "$DISPATCHER_DIR"

echo -e "--> Installing NetworkManager dispatcher scripts..."
install -m 755 "$SCRIPT_DIR/dispatcher/99-seamless-adb.sh" "$DISPATCHER_DIR/99-seamless-adb.sh"
install -m 755 "$SCRIPT_DIR/dispatcher/99-seamless-ftp.sh" "$DISPATCHER_DIR/99-zz-seamless-ftp.sh"

# 3. Create initial bookmark in Dolphin and GTK
echo -e "--> Configuring initial file manager bookmarks..."
python3 /usr/local/bin/seamless-update-places "192.168.43.1" "2121" "$REAL_HOME" >/dev/null 2>&1 || true

# 4. Display Wi-Fi MAC Address
echo ""
echo -e "${BLUE}========================================================${NC}"
echo -e "${GREEN}Laptop Hardware MAC Address (Wi-Fi):${NC}"
for iface in /sys/class/net/*; do
    name=$(basename "$iface")
    if [ -d "$iface/wireless" ] || [[ "$name" =~ ^(wl|wlan|wifi) ]]; then
        mac=$(cat "$iface/address" 2>/dev/null)
        echo -e "  Interface: ${YELLOW}$name${NC}  -->  MAC: ${GREEN}$mac${NC}"
    fi
done
echo -e "${BLUE}========================================================${NC}"
echo -e "📱 Enter this MAC address in the Seamless Connect Android app"
echo -e "   or run: 'seamless-ctl add-mac <MAC>' in root shell on phone."
echo ""

# Restart NetworkManager
echo -e "--> Restarting NetworkManager service..."
systemctl restart NetworkManager 2>/dev/null || true

echo -e "${GREEN}Seamless Connect installed successfully!${NC}"
echo -e "When you connect to your phone's hotspot:"
echo -e "  1. ADB TCP/IP connects automatically."
echo -e "  2. The secure FTP server starts on the phone."
echo -e "  3. 'Phone (FTP)' in Dolphin / Nemo / Nautilus points to your phone's current IP."
