#!/usr/bin/env bash
# 99-seamless-ftp.sh — NetworkManager Dispatcher for Seamless Connect FTP & Bookmarks
# Auto-starts the phone FTP daemon over ADB and updates Dolphin & GTK bookmarks.
# Runs AFTER 99-seamless-adb.sh in lexical order.

INTERFACE="$1"
ACTION="$2"

case "$ACTION" in
    up|dhcp4-change) ;;
    *) exit 0 ;;
esac

# WiFi interfaces only
[[ "$INTERFACE" != w* ]] && exit 0

PORT=2121
log() { logger -t seamless-ftp "$*"; }

# Detect default gateway and resolve Phone IP (Hotspot or LAN discovery)
GW=$(ip route show default dev "$INTERFACE" 2>/dev/null | awk '/default/{print $3; exit}')
PHONE_IP="$GW"
DISCOVER_BIN="/usr/local/bin/seamless-discover"
if [ -x "$DISCOVER_BIN" ]; then
    RESOLVED_IP=$(python3 "$DISCOVER_BIN" "$GW" 2>/dev/null)
    [ -n "$RESOLVED_IP" ] && PHONE_IP="$RESOLVED_IP"
fi

[ -z "$PHONE_IP" ] && { log "No phone IP found on $INTERFACE — skipping"; exit 0; }

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
UID_VAL=$(id -u "$DESKTOP_USER" 2>/dev/null || echo 1000)
ADB_BIN=$(which adb 2>/dev/null || echo "/usr/bin/adb")

as_user() {
    runuser -u "$DESKTOP_USER" -- env \
        HOME="$USER_HOME" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID_VAL}/bus" \
        PATH="/usr/local/bin:/usr/bin:/bin:$PATH" \
        "$@" 2>&1
}

adb_user() {
    as_user "$ADB_BIN" "$@"
}

# Verify ADB connection to this specific phone IP
connected() {
    adb_user devices | grep -q "^${PHONE_IP}:5555[[:space:]]*device"
}

log "Waiting for ADB connection to ${PHONE_IP}:5555..."
for _ in 1 2 3 4 5 6; do
    connected && break
    sleep 2
done

if ! connected; then
    log "ADB not connected to ${PHONE_IP}:5555 — skipping FTP start"
    exit 0
fi

# Start (or refresh) phone-side FTP server
OUT=$(adb_user -s "${PHONE_IP}:5555" shell su -c "
    if [ -x /data/adb/seamless_connect/ftp-server.sh ]; then
        /data/adb/seamless_connect/ftp-server.sh start
    elif [ -x /data/adb/ftp-server.sh ]; then
        /data/adb/ftp-server.sh start
    else
        echo 'Seamless FTP script not found on device'
    fi
" 2>&1)
log "ftp-server start on ${PHONE_IP}: ${OUT}"

# Update Dolphin and GTK bookmarks with current phone IP
UPDATE_SCRIPT="/usr/local/bin/seamless-update-places"
if [ -x "$UPDATE_SCRIPT" ]; then
    as_user python3 "$UPDATE_SCRIPT" "$PHONE_IP" "$PORT" "$USER_HOME" | logger -t seamless-ftp
else
    # Fallback to direct GTK bookmark update
    BOOKMARKS="$USER_HOME/.config/gtk-3.0/bookmarks"
    if [ -f "$BOOKMARKS" ]; then
        NEW_BKMK="ftp://phone:phone@${PHONE_IP}:${PORT}/ Phone (FTP)"
        if grep -q "Phone (FTP)" "$BOOKMARKS"; then
            as_user sed -i "s|ftp://.* Phone (FTP)|$NEW_BKMK|" "$BOOKMARKS"
        else
            as_user bash -c "echo '$NEW_BKMK' >> '$BOOKMARKS'"
        fi
        log "Updated GTK bookmark -> $NEW_BKMK"
    fi
fi

exit 0
