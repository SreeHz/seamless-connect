# customize.sh — Seamless Connect Magisk/KSU/APatch installer
ui_print "****************************************"
ui_print "*        Seamless Connect v1.0         *"
ui_print "*    Wireless ADB & MAC-Locked FTP     *"
ui_print "****************************************"

CONF_DIR="/data/adb/seamless_connect"
mkdir -p "$CONF_DIR"

ui_print "- Installing core scripts to $CONF_DIR..."
cp "$MODPATH/files/ftp-server.sh" "$CONF_DIR/ftp-server.sh"
chmod 755 "$CONF_DIR/ftp-server.sh"
cp "$MODPATH/system/bin/seamless-ctl" "$CONF_DIR/seamless-ctl"
chmod 755 "$CONF_DIR/seamless-ctl"

# Install default configuration if none exists
if [ ! -f "$CONF_DIR/seamless.conf" ]; then
    ui_print "- Creating default seamless.conf..."
    cp "$MODPATH/files/seamless.conf" "$CONF_DIR/seamless.conf"
    chmod 644 "$CONF_DIR/seamless.conf"
else
    ui_print "- Existing seamless.conf preserved."
fi

# Ensure authorized_macs file exists without clobbering existing
if [ ! -f "$CONF_DIR/authorized_macs" ]; then
    ui_print "- Creating authorized_macs file..."
    touch "$CONF_DIR/authorized_macs"
    chmod 644 "$CONF_DIR/authorized_macs"
else
    ui_print "- Existing authorized_macs preserved."
fi

# Legacy compatibility symlink so old scripts don't break
ln -sf "$CONF_DIR/ftp-server.sh" /data/adb/ftp-server.sh

# Set permissions for system binaries
set_perm_recursive "$MODPATH/system/bin" 0 0 0755 0755

ui_print ""
ui_print "- Installation complete!"
ui_print "- Use the 'Seamless Connect' Android app or run"
ui_print "  'seamless-ctl' in a root terminal to configure MACs."
ui_print "****************************************"
