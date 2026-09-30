#!/usr/bin/env python3
"""
update-filemanagers.py — Seamless Connect File Manager Places Sync
Dynamically updates Dolphin (KDE Places XML) and GTK (Nautilus/Nemo/Thunar) bookmarks
with the current Phone Hotspot IP and Port.
"""
import sys
import os
import re
import xml.etree.ElementTree as ET

def fix_ownership(path, home_dir):
    try:
        stat_info = os.stat(home_dir)
        os.chown(path, stat_info.st_uid, stat_info.st_gid)
    except Exception:
        pass

def update_gtk_bookmarks(home_dir, gateway, port):
    gtk_path = os.path.join(home_dir, ".config", "gtk-3.0", "bookmarks")
    target_entry = f"ftp://phone:phone@{gateway}:{port}/ Phone (FTP)"
    
    os.makedirs(os.path.dirname(gtk_path), exist_ok=True)
    fix_ownership(os.path.dirname(gtk_path), home_dir)
    lines = []
    found = False
    
    if os.path.exists(gtk_path):
        with open(gtk_path, "r", encoding="utf-8") as f:
            for line in f:
                stripped = line.strip()
                if "Phone (FTP)" in stripped:
                    lines.append(target_entry + "\n")
                    found = True
                elif stripped:
                    lines.append(line)
                    
    if not found:
        lines.append(target_entry + "\n")
        
    with open(gtk_path, "w", encoding="utf-8") as f:
        f.writelines(lines)
    fix_ownership(gtk_path, home_dir)
    print(f"[GTK] Updated {gtk_path} -> {target_entry}")

def update_dolphin_places(home_dir, gateway, port):
    places_dir = os.path.join(home_dir, ".local", "share")
    places_path = os.path.join(places_dir, "user-places.xbel")
    new_href = f"ftp://phone:phone@{gateway}:{port}/"

    # If file doesn't exist, create standard XBEL template
    if not os.path.exists(places_path):
        os.makedirs(places_dir, exist_ok=True)
        xml_template = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xbel>
<xbel xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"
      xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info"
      xmlns:kdeprivate="http://www.kde.org/kdeprivate">
  <bookmark href="{new_href}">
    <title>Phone (FTP)</title>
    <info>
      <metadata owner="http://freedesktop.org">
        <bookmark:icon name="phone"/>
      </metadata>
      <metadata owner="http://www.kde.org">
        <ID>seamless_connect_phone_ftp</ID>
        <isSystemItem>false</isSystemItem>
      </metadata>
    </info>
  </bookmark>
</xbel>
"""
        with open(places_path, "w", encoding="utf-8") as f:
            f.write(xml_template)
        fix_ownership(places_path, home_dir)
        print(f"[Dolphin] Created {places_path} with Phone (FTP) bookmark")
        return

    # Parse and update existing user-places.xbel
    try:
        with open(places_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Try fast regex replacement first if already present
        if 'Phone (FTP)' in content:
            # Replace existing href for Phone (FTP)
            pattern = r'(<bookmark\s+href=")[^"]*(">\s*<title>Phone \(FTP\)</title>)'
            if re.search(pattern, content):
                content = re.sub(pattern, rf'\g<1>{new_href}\g<2>', content)
            else:
                # Alternate tag order
                alt_pattern = r'(<bookmark\s+href="ftp://[^"]*">(\s*<title>Phone \(FTP\)</title>))'
                content = re.sub(r'href="ftp://[^"]*"(?=[^<]*<title>Phone \(FTP\)</title>)', f'href="{new_href}"', content)
            with open(places_path, "w", encoding="utf-8") as f:
                f.write(content)
            fix_ownership(places_path, home_dir)
            print(f"[Dolphin] Updated existing bookmark in {places_path} -> {new_href}")
            return
        
        # If bookmark not found in existing xbel, append it before </xbel>
        new_bookmark_node = f"""  <bookmark href="{new_href}">
    <title>Phone (FTP)</title>
    <info>
      <metadata owner="http://freedesktop.org">
        <bookmark:icon name="phone"/>
      </metadata>
      <metadata owner="http://www.kde.org">
        <ID>seamless_connect_phone_ftp</ID>
        <isSystemItem>false</isSystemItem>
      </metadata>
    </info>
  </bookmark>
</xbel>"""
        if "</xbel>" in content:
            content = content.replace("</xbel>", new_bookmark_node)
            with open(places_path, "w", encoding="utf-8") as f:
                f.write(content)
            fix_ownership(places_path, home_dir)
            print(f"[Dolphin] Injected Phone (FTP) into {places_path}")
        else:
            print(f"[Dolphin] Warning: </xbel> closing tag not found in {places_path}")

    except Exception as e:
        print(f"[Dolphin] Error updating places: {e}")

def main():
    if len(sys.argv) < 3:
        print("Usage: update-filemanagers.py <gateway_ip> <port> [target_user_home]")
        sys.exit(1)
        
    gateway = sys.argv[1]
    port = sys.argv[2]
    
    if len(sys.argv) >= 4:
        home_dir = sys.argv[3]
    else:
        home_dir = os.path.expanduser("~")
        
    update_gtk_bookmarks(home_dir, gateway, port)
    update_dolphin_places(home_dir, gateway, port)

if __name__ == "__main__":
    main()
