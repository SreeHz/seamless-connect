package com.seamlessconnect;

import java.util.ArrayList;
import java.util.List;

public class DeviceManager {
    public static final String MACS_FILE = "/data/adb/seamless_connect/authorized_macs";
    public static final String CONF_FILE = "/data/adb/seamless_connect/seamless.conf";
    public static final String FTP_SCRIPT = "/data/adb/seamless_connect/ftp-server.sh";

    public static class Device {
        public String name;
        public String mac;

        public Device(String mac, String name) {
            this.mac = mac.toLowerCase().trim();
            this.name = name != null && !name.trim().isEmpty() ? name.trim() : "Authorized Device";
        }
    }

    public static List<Device> loadAuthorizedDevices() {
        List<Device> devices = new ArrayList<>();
        RootHelper.CommandResult res = RootHelper.runSu("cat " + MACS_FILE + " 2>/dev/null");
        if (res.exitCode == 0 && !res.stdout.isEmpty()) {
            String[] lines = res.stdout.split("\n");
            for (String line : lines) {
                line = line.trim();
                if (line.isEmpty() || line.startsWith("#")) continue;
                String mac = line;
                String name = "Laptop / PC";
                if (line.contains("#")) {
                    String[] parts = line.split("#", 2);
                    mac = parts[0].trim();
                    name = parts[1].trim();
                } else if (line.contains(" ")) {
                    String[] parts = line.split("\\s+", 2);
                    mac = parts[0].trim();
                    name = parts[1].trim();
                }
                if (mac.matches("^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$")) {
                    devices.add(new Device(mac, name));
                }
            }
        }
        return devices;
    }

    public static boolean saveAuthorizedDevices(List<Device> devices) {
        StringBuilder sb = new StringBuilder();
        sb.append("# Seamless Connect Authorized Devices\\n");
        for (Device d : devices) {
            sb.append(d.mac.toLowerCase()).append(" # ").append(d.name).append("\\n");
        }
        String cmd = "mkdir -p /data/adb/seamless_connect && printf \"" + sb.toString() + "\" > " + MACS_FILE + " && chmod 644 " + MACS_FILE;
        RootHelper.CommandResult res = RootHelper.runSu(cmd);
        
        // If FTP server is currently active, restart to update iptables immediately
        refreshFirewall();
        return res.exitCode == 0;
    }

    public static boolean addDevice(String mac, String name) {
        List<Device> list = loadAuthorizedDevices();
        String cleanMac = mac.toLowerCase().trim();
        // Remove if existing
        for (int i = list.size() - 1; i >= 0; i--) {
            if (list.get(i).mac.equalsIgnoreCase(cleanMac)) {
                list.remove(i);
            }
        }
        list.add(new Device(cleanMac, name));
        return saveAuthorizedDevices(list);
    }

    public static boolean removeDevice(String mac) {
        List<Device> list = loadAuthorizedDevices();
        String cleanMac = mac.toLowerCase().trim();
        boolean removed = false;
        for (int i = list.size() - 1; i >= 0; i--) {
            if (list.get(i).mac.equalsIgnoreCase(cleanMac)) {
                list.remove(i);
                removed = true;
            }
        }
        if (removed) {
            saveAuthorizedDevices(list);
        }
        return removed;
    }

    public static boolean isMacAuthorized(String mac, List<Device> authorized) {
        if (mac == null) return false;
        for (Device d : authorized) {
            if (d.mac.equalsIgnoreCase(mac.trim())) return true;
        }
        return false;
    }

    public static void refreshFirewall() {
        RootHelper.runSu("if [ -f /data/local/tmp/ftp-server.state ]; then " +
                "sh " + FTP_SCRIPT + " restart >/dev/null 2>&1; " +
                "fi");
    }
}
