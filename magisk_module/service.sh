#!/system/bin/sh
# service.sh — Seamless Connect Boot Service (Magisk / KernelSU / APatch)
# Runs in background after boot completion

MODDIR=${0%/*}
CONF_DIR="/data/adb/seamless_connect"
CONF_FILE="$CONF_DIR/seamless.conf"

# Wait for boot completion (timeout 120s)
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 60 ]; do
    sleep 2
    i=$((i + 1))
done

sleep 10

# Load config
ENABLE_ADB_PERSIST=1
if [ -f "$CONF_FILE" ]; then
    . "$CONF_FILE"
fi

# Ensure ADB TCP/IP port 5555 if configured
if [ "$ENABLE_ADB_PERSIST" = "1" ]; then
    CURRENT_PORT=$(getprop service.adb.tcp.port)
    if [ "$CURRENT_PORT" != "5555" ]; then
        setprop service.adb.tcp.port 5555
        stop adbd 2>/dev/null
        start adbd 2>/dev/null
    fi
fi

# Ensure executable permissions on scripts
chmod 755 /data/adb/seamless_connect/*.sh 2>/dev/null
chmod 755 "$MODDIR/system/bin/seamless-ctl" 2>/dev/null
exit 0
