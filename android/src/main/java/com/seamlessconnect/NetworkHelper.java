package com.seamlessconnect;

import java.io.BufferedReader;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.List;

public class NetworkHelper {

    public static class HotspotClient {
        public String ip;
        public String mac;
        public String iface;
        public String status;
        public boolean isAuthorized;

        public HotspotClient(String ip, String mac, String iface, String status, boolean isAuthorized) {
            this.ip = ip;
            this.mac = mac.toLowerCase().trim();
            this.iface = iface;
            this.status = status;
            this.isAuthorized = isAuthorized;
        }
    }

    public static class ServiceState {
        public boolean isFtpRunning;
        public int ftpPort;
        public int adbPort;
        public String hotspotIp;
        public String iface;
        public int activePid;
    }

    public static ServiceState getServiceState() {
        ServiceState state = new ServiceState();
        state.ftpPort = 2121;
        state.adbPort = 5555;
        state.hotspotIp = "Unavailable";
        state.iface = "Unknown";
        state.isFtpRunning = false;

        // Check ADB Port
        RootHelper.CommandResult adbRes = RootHelper.runSu("getprop service.adb.tcp.port");
        try {
            if (!adbRes.stdout.isEmpty()) {
                state.adbPort = Integer.parseInt(adbRes.stdout.trim());
            }
        } catch (Exception ignored) {}

        // Check FTP state
        RootHelper.CommandResult ftpRes = RootHelper.runSu(
                "if [ -f /data/local/tmp/ftp-server.state ]; then " +
                ". /data/local/tmp/ftp-server.state 2>/dev/null; " +
                "if kill -0 \"$TCPSVD_PID\" 2>/dev/null; then " +
                "echo \"RUNNING:$TCPSVD_PID:$PORT:$IFACE\"; " +
                "else echo \"STOPPED\"; fi; " +
                "else echo \"STOPPED\"; fi");

        if (ftpRes.stdout.startsWith("RUNNING")) {
            state.isFtpRunning = true;
            String[] parts = ftpRes.stdout.split(":");
            if (parts.length >= 2) {
                try { state.activePid = Integer.parseInt(parts[1]); } catch (Exception ignored) {}
            }
            if (parts.length >= 3) {
                try { state.ftpPort = Integer.parseInt(parts[2]); } catch (Exception ignored) {}
            }
            if (parts.length >= 4) {
                state.iface = parts[3];
            }
        }

        // Detect Hotspot IP & Interface
        RootHelper.CommandResult netRes = RootHelper.runSu(
                "ip -4 route show 2>/dev/null | awk '!/default/ && !/rmnet/ && !/lo/ && /src/ {print $3, $NF}' | head -n 1");
        if (!netRes.stdout.isEmpty()) {
            String[] parts = netRes.stdout.split("\\s+");
            if (parts.length >= 2) {
                state.iface = parts[0];
                state.hotspotIp = parts[1];
            }
        }

        return state;
    }

    public static List<HotspotClient> getConnectedClients(List<DeviceManager.Device> authorized) {
        List<HotspotClient> clients = new ArrayList<>();

        // Check ip neigh show
        RootHelper.CommandResult res = RootHelper.runSu("ip neigh show 2>/dev/null | grep -E 'lladdr'");
        if (!res.stdout.isEmpty()) {
            String[] lines = res.stdout.split("\n");
            for (String line : lines) {
                line = line.trim();
                // e.g.: 10.236.58.241 dev wlan2 lladdr f8:3d:c6:d8:84:9a REACHABLE
                String[] tokens = line.split("\\s+");
                if (tokens.length >= 5) {
                    String ip = tokens[0];
                    String iface = tokens[2];
                    String mac = tokens[4].toLowerCase();
                    String status = tokens.length >= 6 ? tokens[5] : "CONNECTED";
                    if (mac.matches("^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$")) {
                        boolean isAuth = DeviceManager.isMacAuthorized(mac, authorized);
                        clients.add(new HotspotClient(ip, mac, iface, status, isAuth));
                    }
                }
            }
        }

        // Also check /proc/net/arp as fallback
        if (clients.isEmpty()) {
            try {
                BufferedReader br = new BufferedReader(new FileReader("/proc/net/arp"));
                String line;
                boolean first = true;
                while ((line = br.readLine()) != null) {
                    if (first) { first = false; continue; }
                    String[] tokens = line.trim().split("\\s+");
                    if (tokens.length >= 6) {
                        String ip = tokens[0];
                        String mac = tokens[3].toLowerCase();
                        String iface = tokens[5];
                        if (mac.matches("^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$") && !mac.equals("00:00:00:00:00:00")) {
                            boolean isAuth = DeviceManager.isMacAuthorized(mac, authorized);
                            clients.add(new HotspotClient(ip, mac, iface, "ARP", isAuth));
                        }
                    }
                }
                br.close();
            } catch (Exception ignored) {}
        }

        return clients;
    }

    public static boolean startFtpServer() {
        RootHelper.CommandResult res = RootHelper.runSu(
                "if [ -x /data/adb/seamless_connect/ftp-server.sh ]; then " +
                "/data/adb/seamless_connect/ftp-server.sh start; " +
                "elif [ -x /data/adb/ftp-server.sh ]; then " +
                "/data/adb/ftp-server.sh start; fi");
        return res.exitCode == 0;
    }

    public static boolean stopFtpServer() {
        RootHelper.CommandResult res = RootHelper.runSu(
                "if [ -x /data/adb/seamless_connect/ftp-server.sh ]; then " +
                "/data/adb/seamless_connect/ftp-server.sh stop; " +
                "elif [ -x /data/adb/ftp-server.sh ]; then " +
                "/data/adb/ftp-server.sh stop; fi");
        return res.exitCode == 0;
    }

    public static boolean triggerMediaScan() {
        RootHelper.CommandResult res = RootHelper.runSu(
                "content call --uri content://media --method scan_volume --arg external_primary");
        return res.exitCode == 0;
    }
}
