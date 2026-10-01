# 🐧🤖 Seamless Connect

> **Build your own "Apple Ecosystem" Continuity with Linux, Android, and Open Standards.**  
> Zero-Click Wireless ADB + Instant Root FTP File Sharing with Hardware MAC Security & Dolphin Places Auto-Mount.  
> Works seamlessly on **Phone Hotspot** and **Shared Wi-Fi Networks**.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Android Root](https://img.shields.io/badge/Root-Magisk%20%7C%20KernelSU%20%7C%20APatch-brightgreen.svg)](#-android-phone-setup)
[![Linux Compatibility](https://img.shields.io/badge/Linux-KDE%20Dolphin%20%7C%20Nemo%20%7C%20Nautilus-orange.svg)](#-linux-laptop-setup)
[![Network Mode](https://img.shields.io/badge/Network-Hotspot%20%2B%20Home%20Wi--Fi%20(LAN)-purple.svg)](#-two-network-modes)

---

## 💥 The Manifesto: Breaking the "Ecosystem" Myth

Certain Cupertino-based companies love to boast about their "Ecosystem."  
*AirDrop this. Continuity that. Your phone rings on your laptop. Your cloud bills pile up.*  
They sell the illusion that "it just works" is proprietary magic requiring a $2,500 laptop, an overpriced phone, and total surrender to a walled garden.

**We reject that myth.**

There is **nothing** that a proprietary walled garden can do that a Linux machine and a rooted Android phone cannot do better, faster, and completely handsfree. Under the glossy marketing, "Continuity" is just networking, standard protocols, and kernel firewalling.

**Seamless Connect** proves this. Two pillars hold it up:

1. **Handsfree Wireless ADB (TCP/IP)**: The moment your laptop and phone see each other, Wireless ADB reconnects automatically. No USB cables. No hunting for dongles. No typing IP addresses.
2. **Instant Handsfree Root File Sharing (FTP + Places Sync)**: Your phone's entire filesystem mounts in your Linux file manager (KDE Dolphin, Nemo, Nautilus) under a pinned **"Phone (FTP)"** bookmark. Files fly back and forth wirelessly at maximum Wi-Fi speeds.

No corporate gatekeepers. No subscriptions. Just Linux, Android, and open source audacity.

---

## 🌐 Two Network Modes (Always Ready)

Whether you are traveling or sitting at your desk, Seamless Connect is always ready:

| Connection Scenario | How it Works | Detection Mechanism |
| :--- | :--- | :--- |
| **1. Phone Hotspot (On the Go)** | Laptop connects to Phone's Wi-Fi hotspot. The phone is the default gateway. | NetworkManager dispatcher detects default gateway and connects immediately via fast-path. |
| **2. Same Wi-Fi Network (Home / Office LAN)** | Both laptop and phone connect to the same home/office Wi-Fi router. Phone is a peer device on the subnet. | Laptop broadcasts `SEAMLESS_DISCOVER` on UDP `21210`. The phone's companion app replies with its LAN IP. Connection is established instantly! |

---

## 🛡️ The Bouncer: Hardware MAC-Locked Security

Unlike standard FTP servers that require clumsy passwords (or worse, leave doors open to anyone on the Wi-Fi), Seamless Connect uses **Linux Kernel Netfilter (`iptables`)** directly on the phone:

- **Passwordless Root Access**: BusyBox `ftpd` runs with `-A` (anonymous root mode), allowing zero-click browsing.
- **Hardware MAC Whitelist**: `iptables` inspects incoming packets at the physical layer:
  ```bash
  iptables -I INPUT 1 -i <iface> -p tcp --dport 2121 -m mac --mac-source <LAPTOP_MAC> -j ACCEPT
  iptables -A INPUT -i <iface> -p tcp --dport 2121 -j DROP
  ```
  **Only packets originating from your authorized laptop's Wi-Fi hardware MAC address are accepted.** Any other phone, tablet, or neighbor on the network is dropped silently at the kernel level.
- **Dynamic DHCP Immunity**: Even if your laptop receives a new IP address every time it connects, your hardware MAC remains constant. You never have to re-authenticate.

---

## 📱 Material Design Android Companion App

Seamless Connect includes a native Android Companion App ([`SeamlessConnect.apk`](build/release/SeamlessConnect.apk)) featuring a modern Material Design OLED dark theme:

```text
┌────────────────────────────────────────────────────────┐
│  Seamless Connect                      [ REFRESH ]     │
│  Wireless Continuity • ADB & Root FTP                  │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │  ● FTP RUNNING                         ADB: 5555 │  │
│  │  FTP Server Active (Port 2121)                   │  │
│  │  IP: 10.236.58.173 • Iface: wlan2 • Port: 2121   │  │
│  │                                                  │  │
│  │  [▶ Start FTP]     [⏹ Stop FTP]      [🔄 Rescan] │  │
│  └──────────────────────────────────────────────────┘  │
│  🌐 LAN & Hotspot Auto-Discovery Active (UDP 21210)    │
├────────────────────────────────────────────────────────┤
│  Connected Network Devices                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │  💻 10.236.58.241                                │  │
│  │     f8:3d:c6:d8:84:9a • REACHABLE                │  │
│  │                                 [ AUTHORIZED ✓ ] │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  Authorized Laptops (Firewall)            [+ Add MAC]  │
│  ┌──────────────────────────────────────────────────┐  │
│  │  🛡️ Work ThinkPad                                │  │
│  │     f8:3d:c6:d8:84:9a                   [Revoke] │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **Live Service Status**: Real-time FTP and ADB port monitoring with glowing status badges.
- **1-Tap Device Authorization**: Scans connected hotspot/LAN clients from kernel ARP tables (`ip neigh`). Simply tap **`+ Authorize`** on your laptop!
- **Auto-Discovery Beacon**: Background UDP responder on port `21210` allows laptops on the same Wi-Fi router to find your phone without manual IP lookup.
- **MediaStore Auto-Rescan**: Trigger or automate media library refresh so uploaded music and photos appear immediately in Android gallery and audio apps.

---

## 🚀 Quick Setup Guide

### 1. Android Phone Setup
1. **Download & Flash Magisk Module**:
   - Grab `seamless_connect_magisk.zip` from [Releases](https://github.com/SreeHz/seamless-connect/releases) or compile using `./build.sh`.
   - Flash in **Magisk**, **KernelSU**, or **APatch**, and reboot.
   *(This installs `SeamlessConnect.apk`, `seamless-ctl`, and boot persistence).*
2. **Open Seamless Connect**:
   - Grant Root (Superuser) permissions when prompted.
   - Connect your laptop to your phone's hotspot (or connect both to your home Wi-Fi).
   - Under **Connected Network Devices**, tap **`+ Authorize`** next to your laptop.

---

### 2. Linux Laptop Setup
1. **Clone and Install**:
   ```bash
   git clone https://github.com/SreeHz/seamless-connect.git
   cd seamless-connect/linux
   sudo ./install.sh
   ```
2. **What this does**:
   - Installs `seamless-discover` and `seamless-update-places` into `/usr/local/bin/`.
   - Configures NetworkManager dispatchers (`99-seamless-adb.sh` and `99-zz-seamless-ftp.sh`).
   - Registers the **"Phone (FTP)"** pinned bookmark in **KDE Dolphin** (`user-places.xbel`) and **GTK file managers** (Nemo, Nautilus, Thunar).
   - Prints your laptop's Wi-Fi hardware MAC address.

That's it! From now on, whenever you join the hotspot or your home Wi-Fi:
- ADB connects automatically.
- The phone starts the FTP server.
- Click **"Phone (FTP)"** in Dolphin or your file manager to browse the phone's entire root filesystem!

---

## 💻 Compatibility Matrix

Seamless Connect is designed from the ground up to be independent of phone OEM skins and Linux desktop environments.

### Android Compatibility
| Android Version | API Level | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Android 17** (LineageOS 24+) | API 37 | ✅ Fully Verified | Tested on Motorola Moto G57 Power (`mumba_g`, LineageOS 24.0-Ext-BETA) |
| **Android 16** (LineageOS 23+) | API 36 | ✅ Fully Verified | Tested on Motorola Moto G57 Power (`mumba_g`) |
| **Android 15 (Vanilla Ice Cream)** | API 35 | ✅ Supported | Native support for wireless debugging & root FTP |
| **Android 14 (Upside Down Cake)** | API 34 | ✅ Supported | Target SDK level |
| **Android 13 (Tiramisu)** | API 33 | ✅ Supported | Full Magisk & KernelSU compatibility |
| **Android 12 / 12L (Snow Cone)** | API 31 / 32 | ✅ Supported | Full support |
| **Android 11 (Red Velvet Cake)** | API 30 | ✅ Supported | Classic TCP and mDNS discovery supported |
| **Android 10 (Q)** | API 29 | ✅ Supported | Supported |
| **Android 9 (Pie) / 8.0 (Oreo)** | API 26–28 | ✅ Supported | Minimum supported version (`minSdkVersion 26`) |

**Supported Root Solutions**:
- **Magisk**: v25.0 – v30.7+ (Recommended)
- **KernelSU**: v0.6.0+
- **APatch**: v0.10.0+
- **BusyBox**: Built into Magisk/KernelSU (provides `tcpsvd` and `ftpd`).

### Linux Compatibility
| Distribution | Versions | Desktop Environments / File Managers | Status |
| :--- | :--- | :--- | :--- |
| **Ubuntu / Kubuntu** | 20.04 LTS, 22.04 LTS, 24.04 LTS+ | **Dolphin** (KDE), **Nautilus** (GNOME) | ✅ Fully Verified |
| **Linux Mint** | 20.x, 21.x, 22.x+ | **Nemo** (Cinnamon), **Caja** (MATE) | ✅ Fully Verified |
| **Debian** | 11 (Bullseye), 12 (Bookworm)+ | **Dolphin**, **Nautilus**, **Thunar** | ✅ Supported |
| **Fedora / RHEL** | 38, 39, 40, 41+ | **Dolphin** (KDE), **Nautilus** (GNOME) | ✅ Supported |
| **Arch Linux / Manjaro** | Rolling (All) | **Dolphin**, **Thunar** (XFCE), **PCManFM** | ✅ Supported |
| **openSUSE** | Tumbleweed, Leap 15.x+ | **Dolphin**, **Nautilus** | ✅ Supported |

**Supported File Managers & Places Engines**:
- **KDE Plasma (Dolphin)**: Auto-synchronizes `~/.local/share/user-places.xbel` XML. Dolphin's `KDirWatch` updates the sidebar in real time without restarting the file manager.
- **GTK File Managers (Nemo, Nautilus, Thunar, PCManFM)**: Auto-synchronizes `~/.config/gtk-3.0/bookmarks`.
- **Network Engine**: Compatible with any Linux system running **NetworkManager** (standard on almost all desktop distributions).

---

## 🧹 The Self-Cleaning Watchdog

What happens when you leave? You can't tell the phone to stop once you've disconnected.

The phone monitors itself:
- A phone-side watchdog ping tests the laptop every 30 seconds.
- It checks ARP neighbor entries (tolerant to Wi-Fi power-save sleep states) and ICMP echo replies.
- After 3 consecutive misses (90s), the watchdog tears down the FTP daemon, clears the firewall rules, and triggers an Android MediaStore rescan.

---

## ⚙️ CLI Management (`seamless-ctl`)

For terminal power users, Seamless Connect includes a comprehensive root CLI on Android:

```bash
su -c "seamless-ctl status"            # View live status, ports, clients & firewall
su -c "seamless-ctl start"             # Start FTP server manually
su -c "seamless-ctl stop"              # Stop FTP server manually
su -c "seamless-ctl clients"           # View connected hotspot/LAN clients
su -c "seamless-ctl list-macs"         # List authorized hardware MACs
su -c "seamless-ctl add-mac <MAC> [N]" # Authorize a laptop MAC address
su -c "seamless-ctl del-mac <MAC>"     # Revoke a laptop MAC address
su -c "seamless-ctl rescan-media"      # Force Android MediaStore library rescan
```

---

## 🏗️ Building from Source

Build the complete Android Companion App and Magisk Module with a single command:

```bash
# Requires Java 17 and Android SDK build-tools
./build.sh
```

Artifacts are produced in `build/release/`:
- `SeamlessConnect.apk`
- `seamless_connect_magisk.zip`

---

## 📜 License & Community

Distributed under the [MIT License](LICENSE).  
Built for Linux users, Android enthusiasts, and anyone who refuses to pay an "ecosystem tax" for basic functionality.

Contributions, feature requests, and pull requests are warmly welcomed!
