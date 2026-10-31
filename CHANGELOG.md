# Changelog

All notable changes to **Seamless Connect** are documented in this file.

## [v1.2.2] - 2026-10-31

### Fixed
- **Phone Daemon (`ftp-server.sh`) Multi-Interface State Clobbering**: Preserved immutable `CFG_IFACE` from `seamless.conf` and isolated `TCPSVD_PID` extraction in a subshell during `teardown` so sourcing `/data/local/tmp/ftp-server.state` no longer overwrites `IFACE="auto"` with a single stale interface (`wlan2`/`wlan0`) on subsequent restarts.
- **Zero-Click Linux GVFS / KDE KIO Anonymous FTP URI**: Updated `update-filemanagers.py` and `99-seamless-ftp.sh` to generate `ftp://anonymous@<ip>:2121/` bookmarks instead of `ftp://phone:phone@<ip>:2121/`, eliminating password prompt popups in Nemo, Nautilus, Thunar, and Dolphin when Android Hotspot randomizes its subnet IP.
- **Linux Boot-Time Desktop User Detection**: Hardened `detect_active_user()` in `99-seamless-adb.sh`, `99-seamless-ftp.sh`, and `install.sh` with UID-based `loginctl` filtering and a `getent passwd` (`1000 <= UID < 60000`) fallback so pre-login boot Wi-Fi connections run ADB and bookmark updates as the real desktop user rather than `root`.
- **Stale `offline` Wireless ADB Socket Auto-Recovery (Linux)**: Added automatic `adb disconnect` + `adb connect` recovery in `99-seamless-adb.sh` and `99-seamless-ftp.sh` when `adb devices` reports an `offline` TCP socket, matching Windows behavior.
- **Linux LAN UDP Auto-Discovery**: Updated `seamless-discover.py` to broadcast `SEAMLESS_DISCOVER` to the `/24` directed subnet broadcast address in addition to `255.255.255.255`.

### Changed
- **Build System (`build.sh`)**: Unified packaging of all four release artifacts (`SeamlessConnect.apk`, `seamless_connect_magisk.zip`, `seamless_connect_linux.zip`, and `seamless_connect_windows.zip`) and synchronized Android companion app version to `1.2.2` (`versionCode=122`).

---

## [v1.2.1] - 2026-10-31

### Fixed
- **Wireless FTP Auto-Start Over ADB (Windows & Linux)**: Single-quoted the `adb shell su -c` command payload in `seamless-connect.ps1` and `99-seamless-ftp.sh` so Android's `/system/bin/sh` preserves the full root command intact.
- **Native Windows File Explorer Network Location (`This PC`)**: Upgraded `update-explorer.ps1` to create a native Windows Shell Folder Shortcut (`CLSID {0AFACED1-E828-11D1-9187-B532F1E9575D}`) inside `Network Shortcuts` with `SHChangeNotify` refresh.
- **Hotspot DHCP Race Protection & Port Verification (Windows)**: Added Wi-Fi gateway polling, `offline` ADB socket recovery, TCP port `2121` reachability checks, and logging.
- **Multi-Interface SoftAP Firewall Rules (`ftp-server.sh`)**: Added ARP/neighbor MAC interface detection and multi-interface `iptables` MAC whitelisting.

---

## [v1.2.0] - 2026-10-15

### Added
- **Native Windows 10/11 Support**: Added Event ID `10000` (`Microsoft-Windows-NetworkProfile/Operational`) scheduled task trigger, PowerShell wireless ADB & UDP discovery orchestrator, File Explorer FTP integration, and automated Google SDK `platform-tools` installer.

---

## [v1.1.0] - 2026-09-30

### Added
- **Creative Adaptive App Icon & Pure Black OLED Status Bar**: Redesigned Android companion app visuals and added comprehensive Android & Linux compatibility matrices.

---

## [v1.0.0] - 2026-09-30

### Added
- **Initial Open-Source Release**: Material Design Android Companion App, Magisk / KernelSU / APatch root module with `iptables` hardware MAC-locked BusyBox `ftpd` and self-cleaning watchdog, LAN UDP auto-discovery beacon, and Linux NetworkManager dispatchers with Dolphin & GTK bookmark sync.
