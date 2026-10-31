#!/system/bin/sh
# ftp-server.sh — Seamless Connect Daemon
# Secure BusyBox FTP server locked to authorized laptop MAC addresses via iptables.
# Supports multiple authorized MACs, dynamic interface auto-detection (including dual Wi-Fi + Hotspot),
# watchdog auto-teardown, and automatic Android MediaStore rescan.

CONF_DIR="/data/adb/seamless_connect"
CONF_FILE="$CONF_DIR/seamless.conf"
MACS_FILE="$CONF_DIR/authorized_macs"
STATE="/data/local/tmp/ftp-server.state"
SCAN_MARKER="/data/local/tmp/ftp-scan.marker"
SCAN_ROOT="/sdcard/"

# Defaults
PORT=2121
IFACE="auto"
WATCH_INTERVAL=30
WATCH_MISSES=3

# Load configuration if present
if [ -f "$CONF_FILE" ]; then
    . "$CONF_FILE"
fi
CFG_IFACE="${IFACE:-auto}"

export PATH=/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

log() {
    echo "$(date '+%m-%d %H:%M:%S') seamless-ftp: $*"
    /system/bin/log -p i -t seamless-ftp "$*" 2>/dev/null
}

find_busybox() {
    for b in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/busybox /system/xbin/busybox $(which busybox 2>/dev/null); do
        if [ -x "$b" ] && "$b" --list 2>/dev/null | grep -q "tcpsvd"; then
            echo "$b"
            return 0
        fi
    done
    return 1
}

get_authorized_macs() {
    if [ -f "$MACS_FILE" ]; then
        grep -v '^[[:space:]]*#' "$MACS_FILE" | grep -v '^[[:space:]]*$' | awk '{print tolower($1)}'
    fi
}

detect_iface() {
    if [ -n "$CFG_IFACE" ] && [ "$CFG_IFACE" != "auto" ]; then
        echo "$CFG_IFACE"
        return 0
    fi
    local detected=""
    # 1. Prefer the interface where an authorized MAC is actively present in ARP/neighbor table
    local macs=$(get_authorized_macs)
    if [ -n "$macs" ]; then
        for mac in $macs; do
            detected=$(ip neigh show 2>/dev/null | awk -v m="$mac" 'tolower($0) ~ tolower(m) {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
            if [ -n "$detected" ]; then
                echo "$detected"
                return 0
            fi
        done
    fi
    # 2. Prefer SoftAP / Hotspot interface (wlan2, wlan1, ap0, swlan0) over client wlan0 when dual Wi-Fi is active
    detected=$(ip -4 route show 2>/dev/null | awk '!/default/ && !/rmnet/ && !/lo/ && /src/ {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | grep -E '^(ap|swlan|wlan[1-9])' | head -n 1)
    if [ -z "$detected" ]; then
        detected=$(ip -4 route show 2>/dev/null | awk '!/default/ && !/rmnet/ && !/lo/ && /src/ {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | grep -E '^(wlan|ap|swlan)' | head -n 1)
    fi
    if [ -z "$detected" ]; then
        detected=$(ip link show 2>/dev/null | grep -E '^[0-9]+: (wlan|ap|swlan)[0-9]' | grep -i 'state UP' | awk -F': ' '{print $2}' | head -n 1)
    fi
    echo "${detected:-wlan0}"
}

ACTIVE_IFACE=$(detect_iface)
BB=$(find_busybox)

add_firewall() {
    local macs=$(get_authorized_macs)
    # Insert global DROP on FTP port first (pushed down below ACCEPT rules as we insert at 1)
    # This ensures port 2121 is closed on ALL interfaces (including public Wi-Fi & cellular) except whitelisted MACs
    iptables -I INPUT 1 -p tcp --dport "$PORT" -j DROP
    iptables -I INPUT 1 -i lo -p tcp --dport "$PORT" -j ACCEPT

    if [ -z "$macs" ]; then
        log "WARNING: No authorized MAC addresses configured in $MACS_FILE! Locking to localhost only."
        return 0
    fi

    if [ -n "$CFG_IFACE" ] && [ "$CFG_IFACE" != "auto" ]; then
        for mac in $macs; do
            iptables -I INPUT 1 -i "$ACTIVE_IFACE" -p tcp --dport "$PORT" -m mac --mac-source "$mac" -j ACCEPT
            iptables -I INPUT 1 -i "$ACTIVE_IFACE" -m mac --mac-source "$mac" -j ACCEPT
        done
    else
        for mac in $macs; do
            iptables -I INPUT 1 -p tcp --dport "$PORT" -m mac --mac-source "$mac" -j ACCEPT
            iptables -I INPUT 1 -m mac --mac-source "$mac" -j ACCEPT
        done
    fi
}

del_firewall() {
    local saved_iface=""
    [ -f "$STATE" ] && saved_iface=$(. "$STATE" 2>/dev/null; echo "$IFACE")
    local macs=$(get_authorized_macs)
    if [ -n "$macs" ]; then
        for mac in $macs; do
            while iptables -D INPUT -p tcp --dport "$PORT" -m mac --mac-source "$mac" -j ACCEPT 2>/dev/null; do :; done
            while iptables -D INPUT -m mac --mac-source "$mac" -j ACCEPT 2>/dev/null; do :; done
            for ifc in $ACTIVE_IFACE $saved_iface wlan0 wlan1 wlan2 ap0 swlan0; do
                [ -z "$ifc" ] && continue
                while iptables -D INPUT -i "$ifc" -p tcp --dport "$PORT" -m mac --mac-source "$mac" -j ACCEPT 2>/dev/null; do :; done
                while iptables -D INPUT -i "$ifc" -m mac --mac-source "$mac" -j ACCEPT 2>/dev/null; do :; done
            done
        done
    fi
    while iptables -D INPUT -i lo -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -p tcp --dport "$PORT" -j DROP 2>/dev/null; do :; done
    for ifc in $ACTIVE_IFACE $saved_iface wlan0 wlan1 wlan2 ap0 swlan0; do
        [ -z "$ifc" ] && continue
        while iptables -D INPUT -i "$ifc" -p tcp --dport "$PORT" -j DROP 2>/dev/null; do :; done
    done
}

media_scan_if_uploads() {
    [ -z "$BB" ] && return 0
    [ -f "$SCAN_MARKER" ] || { touch "$SCAN_MARKER"; return 0; }
    touch "$SCAN_MARKER.new"
    if "$BB" find "$SCAN_ROOT" \( -name Android -o -name '.*' \) -prune \
            -o -type f -newer "$SCAN_MARKER" -print 2>/dev/null | head -n 1 | grep -q .; then
        mv "$SCAN_MARKER.new" "$SCAN_MARKER"
        log "New uploaded files detected — rescanning MediaStore..."
        if content call --uri content://media --method scan_volume --arg external_primary >/dev/null 2>&1; then
            log "MediaStore scan completed successfully"
        else
            log "MediaStore scan call failed"
        fi
    else
        rm -f "$SCAN_MARKER.new"
    fi
}

connected_mac_ip() {
    local target_mac="$1"
    if [ -n "$CFG_IFACE" ] && [ "$CFG_IFACE" != "auto" ]; then
        ip -4 neigh show dev "$ACTIVE_IFACE" 2>/dev/null \
            | awk -v m="$target_mac" 'tolower($0) ~ tolower(m) {print $1; exit}'
    else
        ip -4 neigh show 2>/dev/null \
            | awk -v m="$target_mac" 'tolower($0) ~ tolower(m) {print $1; exit}'
    fi
}

is_laptop_present() {
    local macs=$(get_authorized_macs)
    [ -z "$macs" ] && return 1

    for mac in $macs; do
        if [ -n "$CFG_IFACE" ] && [ "$CFG_IFACE" != "auto" ]; then
            if ip neigh show dev "$ACTIVE_IFACE" 2>/dev/null | grep -qi "$mac"; then
                return 0
            fi
        else
            if ip neigh show 2>/dev/null | grep -qi "$mac"; then
                return 0
            fi
        fi
        local ip=$(connected_mac_ip "$mac")
        if [ -n "$ip" ] && ping -c1 -W2 "$ip" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

teardown() {
    local state_pid=""
    if [ -f "$STATE" ]; then
        state_pid=$(. "$STATE" 2>/dev/null; echo "$TCPSVD_PID")
    fi
    [ -n "$state_pid" ] && kill "$state_pid" 2>/dev/null
    [ -n "$TCPSVD_PID" ] && kill "$TCPSVD_PID" 2>/dev/null
    if [ -n "$BB" ]; then
        pkill -f "$BB ftpd" 2>/dev/null
    else
        pkill -f "ftpd" 2>/dev/null
    fi
    pkill -f "tcpsvd .* $PORT " 2>/dev/null
    media_scan_if_uploads
    del_firewall
    rm -f "$STATE" "$SCAN_MARKER" "$SCAN_MARKER.new"
}

start() {
    if [ -z "$BB" ]; then
        log "ERROR: BusyBox with tcpsvd/ftpd applets not found!"
        return 1
    fi
    stop
    ACTIVE_IFACE=$(detect_iface)
    add_firewall
    touch "$SCAN_MARKER"
    "$BB" tcpsvd -vE 0.0.0.0 "$PORT" "$BB" ftpd -w -A / </dev/null >/dev/null 2>&1 &
    TCPSVD_PID=$!
    "$0" watchdog </dev/null >/dev/null 2>&1 &
    WATCHDOG_PID=$!

    mkdir -p "$(dirname "$STATE")"
    {
        echo "TCPSVD_PID=$TCPSVD_PID"
        echo "WATCHDOG_PID=$WATCHDOG_PID"
        echo "IFACE=$ACTIVE_IFACE"
        echo "PORT=$PORT"
        echo "STARTED=$(date '+%s')"
    } > "$STATE"
    log "Started FTP server on port $PORT (iface: $ACTIVE_IFACE, tcpsvd=$TCPSVD_PID, watchdog=$WATCHDOG_PID)"
}

stop() {
    local wpid=""
    [ -f "$STATE" ] && wpid=$(. "$STATE" 2>/dev/null; echo "$WATCHDOG_PID")
    teardown
    [ -n "$wpid" ] && [ "$wpid" != "$$" ] && kill "$wpid" 2>/dev/null
    log "Stopped FTP server"
}

status() {
    if [ -f "$STATE" ] && . "$STATE" 2>/dev/null && kill -0 "$TCPSVD_PID" 2>/dev/null; then
        local client_info=""
        for mac in $(get_authorized_macs); do
            local cip=$(connected_mac_ip "$mac")
            if [ -n "$cip" ]; then
                client_info="$client_info $mac($cip)"
            fi
        done
        echo "STATUS=RUNNING"
        echo "TCPSVD_PID=$TCPSVD_PID"
        echo "WATCHDOG_PID=$WATCHDOG_PID"
        echo "IFACE=$ACTIVE_IFACE"
        echo "PORT=$PORT"
        echo "CONNECTED_CLIENTS=$client_info"
        echo "--- Firewall Rules ---"
        iptables -S INPUT 2>/dev/null | grep -- "--dport $PORT"
    else
        echo "STATUS=STOPPED"
    fi
}

watchdog() {
    misses=0
    while :; do
        sleep "$WATCH_INTERVAL"
        media_scan_if_uploads
        if is_laptop_present; then
            misses=0
        else
            misses=$((misses + 1))
            log "Authorized laptop absent ($misses/$WATCH_MISSES)"
            if [ "$misses" -ge "$WATCH_MISSES" ]; then
                log "All authorized laptops absent — tearing down FTP daemon"
                teardown
                exit 0
            fi
        fi
    done
}

case "$1" in
    start)    start ;;
    stop)     stop ;;
    restart)  stop; sleep 1; start ;;
    status)   status ;;
    watchdog) watchdog ;;
    scan)     media_scan_if_uploads ;;
    *)        echo "Usage: $0 {start|stop|restart|status|watchdog|scan}"; exit 1 ;;
esac
