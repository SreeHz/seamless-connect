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

# Detect default gateway and resolve Phone IP (Hotspot or LAN discovery)
GW=$(ip route show default dev "$INTERFACE" 2>/dev/null | awk '/default/{print $3; exit}')
PHONE_IP="$GW"
DISCOVER_BIN="/usr/local/bin/seamless-discover"
if [ -x "$DISCOVER_BIN" ]; then
    RESOLVED_IP=$(python3 "$DISCOVER_BIN" "$GW" 2>/dev/null)
    [ -n "$RESOLVED_IP" ] && PHONE_IP="$RESOLVED_IP"
fi

[ -z "$PHONE_IP" ] && { log "No phone IP found on $INTERFACE — skipping"; exit 0; }

# Dynamically detect active desktop user (safe even at boot before GUI login)
detect_active_user() {
    local u=""
    u=$(loginctl list-sessions --no-legend 2>/dev/null | awk '$2 >= 1000 && $2 < 60000 {print $3; exit}')
    if [ -z "$u" ]; then
        u=$(loginctl list-users --no-legend 2>/dev/null | awk '$1 >= 1000 && $1 < 60000 {print $2; exit}')
    fi
    if [ -z "$u" ]; then
        u=$(who 2>/dev/null | awk '$1 != "root" && $1 != "gdm" && $1 != "sddm" && $1 != "lightdm" {print $1; exit}')
    fi
    if [ -z "$u" ]; then
        u=$(getent passwd 2>/dev/null | awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "nobody" {print $1; exit}')
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

log "Network event on $INTERFACE (Phone IP: $PHONE_IP). Connecting ADB as user $DESKTOP_USER..."

adb_as_user() {
    runuser -u "$DESKTOP_USER" -- env HOME="$USER_HOME" "$ADB_BIN" "$@" 2>&1
}

# Recover stale offline ADB socket if present
if adb_as_user devices | grep -q "^${PHONE_IP}:5555[[:space:]]*offline"; then
    log "ADB socket ${PHONE_IP}:5555 is offline; disconnecting first..."
    adb_as_user disconnect "${PHONE_IP}:5555" | logger -t seamless-adb
fi

# Run ADB connect inside the desktop user's session environment
adb_as_user connect "${PHONE_IP}:5555" | logger -t seamless-adb

exit 0
