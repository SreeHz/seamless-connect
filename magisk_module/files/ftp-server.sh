#!/system/bin/sh
# ftp-server.sh — Seamless Connect Daemon
# Secure BusyBox FTP server locked to authorized laptop MAC addresses via iptables.
# Supports multiple authorized MACs, dynamic interface auto-detection, watchdog auto-teardown,
# and automatic Android MediaStore rescan.

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

detect_iface() {
    if [ -n "$IFACE" ] && [ "$IFACE" != "auto" ]; then
        echo "$IFACE"
        return 0
    fi
    local detected=""
    # Check routing table for active tether subnet route
    detected=$(ip -4 route show 2>/dev/null | awk '!/default/ && !/rmnet/ && !/lo/ && /src/ {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | grep -E 'wlan|ap|swlan' | head -n 1)
    if [ -z "$detected" ]; then
        detected=$(ip link show 2>/dev/null | grep -E '^[0-9]+: (wlan|ap|swlan)[0-9]' | grep -i 'state UP' | awk -F': ' '{print $2}' | head -n 1)
    fi
    echo "${detected:-wlan0}"
}

ACTIVE_IFACE=$(detect_iface)
BB=$(find_busybox)

get_authorized_macs() {
    if [ -f "$MACS_FILE" ]; then
        grep -v '^[[:space:]]*#' "$MACS_FILE" | grep -v '^[[:space:]]*$' | awk '{print tolower($1)}'
    fi
}

add_firewall() {
    local macs=$(get_authorized_macs)
    if [ -z "$macs" ]; then
        log "WARNING: No authorized MAC addresses configured in $MACS_FILE! Locking to localhost only."
        iptables -I INPUT 1 -i "$ACTIVE_IFACE" -p tcp --dport "$PORT" -j DROP
        return 0
    fi

    # Insert ACCEPT rules for each authorized MAC
    for mac in $macs; do
        iptables -I INPUT 1 -i "$ACTIVE_IFACE" -p tcp --dport "$PORT" -m mac --mac-source "$mac" -j ACCEPT
        iptables -I INPUT 1 -i "$ACTIVE_IFACE" -m mac --mac-source "$mac" -j ACCEPT
    done
    # Block everyone else on this port
    iptables -A INPUT -i "$ACTIVE_IFACE" -p tcp --dport "$PORT" -j DROP
}

del_firewall() {
    local macs=$(get_authorized_macs)
    if [ -n "$macs" ]; then
        for mac in $macs; do
            while iptables -D INPUT -i "$ACTIVE_IFACE" -p tcp --dport "$PORT" -m mac --mac-source "$mac" -j ACCEPT 2>/dev/null; do :; done
            while iptables -D INPUT -i "$ACTIVE_IFACE" -m mac --mac-source "$mac" -j ACCEPT 2>/dev/null; do :; done
        done
    fi
    # Also clean up DROP rule
    while iptables -D INPUT -i "$ACTIVE_IFACE" -p tcp --dport "$PORT" -j DROP 2>/dev/null; do :; done
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
    ip neigh show dev "$ACTIVE_IFACE" 2>/dev/null \
        | awk -v m="$target_mac" 'tolower($0) ~ tolower(m) {print $1; exit}'
}

is_laptop_present() {
    local macs=$(get_authorized_macs)
    [ -z "$macs" ] && return 1

    for mac in $macs; do
        if ip neigh show dev "$ACTIVE_IFACE" 2>/dev/null | grep -qi "$mac"; then
            return 0
        fi
        local ip=$(connected_mac_ip "$mac")
        if [ -n "$ip" ] && ping -c1 -W2 "$ip" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

teardown() {
    if [ -f "$STATE" ]; then . "$STATE" 2>/dev/null; fi
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
    add_firewall
    touch "$SCAN_MARKER"
    "$BB" tcpsvd -vE 0.0.0.0 "$PORT" "$BB" ftpd -w -A / >/dev/null 2>&1 &
    TCPSVD_PID=$!
    "$0" watchdog >/dev/null 2>&1 &
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
