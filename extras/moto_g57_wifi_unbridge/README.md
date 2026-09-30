# Moto G57 Power (mumba_g) — Wi-Fi Hotspot 2.4/5 GHz Band Unbridge Overlay

### Context & Problem
On Motorola Moto G57 Power (`mumba_g`) running LineageOS 23.2 (Android 16), the ROM advertises bridged (dual-band concurrent) SoftAP capabilities by default. This causes the Android Settings app to collapse the Hotspot band selector into a single "2.4 GHz / 5 GHz" option without allowing the user to force a specific band (e.g. forcing 5 GHz for maximum throughput or 2.4 GHz for legacy IoT).

Fabricated overlays (`cmd overlay fabricate`) crash `idmap2d` or do not persist past reboots on this ROM. Thus, a signed **Static Runtime Resource Overlay (RRO)** targeting `/system/product/overlay` is required.

### Resource Overrides
- `config_wifiBridgedSoftApSupported` = `false`
- `config_wifiSoftapAutoUpgradeToBridgedConfigWhenSupported` = `false`
- Target Package: `com.android.wifi.resources` (`WifiCustomization`)

### Usage
This static overlay can be installed alongside Seamless Connect or flashed independently as a Magisk/KernelSU module if you are using a Moto G57 on LineageOS.
