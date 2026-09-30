#!/usr/bin/env bash
# 99-seamless-adb.sh — NetworkManager Dispatcher for Wireless ADB Auto-Connect
# Auto-connects ADB TCP/IP when joining the Android phone's hotspot.

INTERFACE="$1"
ACTION="$2"

case "$ACTION" in
    up|dhcp4-change) ;;
    *) exit 0 ;;
esac

# WiFi interfaces only
[[ "$INTERFACE" != w* ]] && exit 0

log() { logger -t seamless-adb "$*"; }

# Detect default gateway (phone's AP address)
GW=$(ip route show default dev "$INTERFACE" 2>/dev/null | awk '/default/{print $3; exit}')
[ -z "$GW" ] && { log "No gateway found on $INTERFACE — skipping"; exit 0; }

# Dynamically detect active desktop user
detect_active_user() {
    local u=""
    u=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3}' | while read s_user; do
        if [ "$s_user" != "root" ] && [ "$s_user" != "gdm" ] && [ "$s_user" != "sddm" ] && [ "$s_user" != "lightdm" ]; then
            echo "$s_user"
            break
        fi
    done)
    if [ -z "$u" ]; then
        u=$(loginctl list-users --no-legend 2>/dev/null | awk '$1 >= 1000 {print $2; exit}')
    fi
    if [ -z "$u" ]; then
        u=$(who | awk '$2 ~ /(:0|tty2|wayland)/ {print $1; exit}')
    fi
    echo "${u:-root}"
}

DESKTOP_USER=$(detect_active_user)
USER_HOME=$(eval echo "~$DESKTOP_USER")
ADB_BIN=$(which adb 2>/dev/null || echo "/usr/bin/adb")

if [ ! -x "$ADB_BIN" ]; then
    log "adb binary not found or not executable — skipping"
    exit 0
fi

log "Connected to hotspot on $INTERFACE (Gateway: $GW). Connecting ADB as user $DESKTOP_USER..."

# Run ADB connect inside the desktop user's session environment
runuser -u "$DESKTOP_USER" -- env \
    HOME="$USER_HOME" \
    "$ADB_BIN" connect "${GW}:5555" 2>&1 | logger -t seamless-adb

exit 0
