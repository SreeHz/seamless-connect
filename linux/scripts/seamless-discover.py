#!/usr/bin/env python3
"""
seamless-discover.py — Network Auto-Discovery for Seamless Connect
Finds the phone IP whether connected to the phone's Hotspot or to a shared Wi-Fi router.
"""
import sys
import socket
import subprocess

def test_adb_port(ip, port=5555, timeout=0.8):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect((ip, port))
        s.close()
        return True
    except Exception:
        return False

def discover_udp(timeout=2.0):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    s.settimeout(timeout)
    
    # Broadcast discovery message
    try:
        s.sendto(b"SEAMLESS_DISCOVER", ("255.255.255.255", 21210))
        # Also try direct subnet broadcasts
        for target in ["255.255.255.255"]:
            try:
                s.sendto(b"SEAMLESS_DISCOVER", (target, 21210))
            except Exception:
                pass

        data, addr = s.recvfrom(1024)
        msg = data.decode().strip()
        if msg.startswith("SEAMLESS_OFFER"):
            parts = msg.split(":")
            phone_ip = parts[1] if len(parts) > 1 and parts[1] != "Unavailable" else addr[0]
            return phone_ip
    except socket.timeout:
        pass
    except Exception as e:
        pass
    finally:
        s.close()
    return None

def main():
    gateway = sys.argv[1] if len(sys.argv) > 1 else None

    # 1. Hotspot Fast-Path: If gateway responds to ADB port 5555, phone is the hotspot gateway
    if gateway and test_adb_port(gateway, 5555):
        print(gateway)
        sys.exit(0)

    # 2. Shared Wi-Fi / LAN Path: Broadcast discovery beacon to find phone IP on local network
    phone_ip = discover_udp(timeout=2.0)
    if phone_ip:
        print(phone_ip)
        sys.exit(0)

    # 3. Fallback: If gateway was provided and nothing else answered, return gateway
    if gateway:
        print(gateway)
        sys.exit(0)

    sys.exit(1)

if __name__ == "__main__":
    main()
