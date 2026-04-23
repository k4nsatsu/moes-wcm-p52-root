# MOES WCM-P52 — Root Access & Firmware Liberation

> Full root shell on a Tuya-based IP camera running Ingenic T31 — **no soldering, no flash desoldering, no special equipment required.** Just an SD card.

![Ingenic T31](https://img.shields.io/badge/SoC-Ingenic%20T31-blue)
![Tuya](https://img.shields.io/badge/Firmware-TuyaOS%206.2.2-orange)
![License](https://img.shields.io/badge/License-MIT-green)

---

## ⚠️ Disclaimer

This guide is intended for use on **devices you own**. The goal is to replace the proprietary Tuya firmware with open-source alternatives such as [OpenIPC](https://openipc.org) or [Thingino](https://thingino.com), restoring privacy, enabling local-only operation, and giving you full control over your own hardware.

---

## The Problem

The MOES WCM-P52 works normally but requires the **Tuya cloud** for full functionality. Although ONVIF local streaming is possible, after approximately 24 hours the camera enters a "ghost mode" and stops responding entirely. The only permanent fix is replacing the firmware.

---

## The Solution

By analyzing the original firmware with `binwalk`, SD card automount scripts were found. The camera's **factory test mechanism** executes arbitrary scripts from an SD card **with no signature verification**. This is the entry point.

```
SD inserted
    └── mdev triggers automount.sh
            └── mounts SD at /mnt/mmcblk0p1
                    └── runs ./unzip -o ./t31.zip -d /tmp
                            └── calls ty_sdcard_check_factory.sh /tmp
                                    └── executes /tmp/tuya/fac/script/ty_auto_test.sh ← PAYLOAD
```

---

## Quick Start

**What you need:**

- SD card (any size, will be formatted)
- A computer with Docker installed
- ~10 minutes

```bash
# 1. Format SD card as FAT32 MBR (replace diskN)
diskutil eraseDisk MS-DOS TUYA MBRFormat /dev/diskN

# 2. Clone this repo
git clone https://github.com/YOUR_USERNAME/moes-wcm-p52-root
cd moes-wcm-p52-root

# 3. Build MIPS binaries and prepare the SD card
./payload/build-mips-binaries.sh /Volumes/TUYA

# 4. Safely eject and insert SD into the powered-on camera
diskutil eject /dev/diskN

# 5. Wait ~30 seconds, then connect
ssh root@<CAMERA_IP>        # password: root
# or
telnet <CAMERA_IP> 23
```

---

## Documentation

| Doc                                               | Description                            |
| ------------------------------------------------- | -------------------------------------- |
| [Hardware](docs/01-hardware.md)                   | Specs, UART pinout, partition layout   |
| [Firmware Analysis](docs/02-firmware-analysis.md) | binwalk, scripts, discovery process    |
| [SD Card Payload](docs/03-sd-payload.md)          | Step-by-step root access guide         |
| [UART Access](docs/04-uart-access.md)             | Alternative method with serial adapter |
| [Firmware Backup](docs/05-firmware-backup.md)     | Full partition dump & restore          |
| [Next Steps](docs/06-next-steps.md)               | OpenIPC / Thingino — work in progress  |

---

## Hardware

| Component    | Model                          |
| ------------ | ------------------------------ |
| Camera       | MOES WCM-P52                   |
| SoC          | Ingenic T31                    |
| Flash        | XMC25QH64C (64Mbit SPI NOR)    |
| RAM          | 64MB DDR                       |
| WiFi         | ATBM6012B-X                    |
| Image Sensor | SC3336                         |
| OS           | Linux 3.10.14 + BusyBox 1.22.1 |
| Firmware     | TuyaOS SDK 6.2.2               |

---

## Development Environment

- MacBook Pro M3 (macOS)
- USB-UART adapter (CH340/CP2102) — optional
- SD card formatted FAT32 MBR
- Docker Desktop for MIPS cross-compilation

---

## References

- [OpenIPC — Ingenic T31](https://openipc.org/cameras/vendors/ingenic/socs/t31)
- [Thingino](https://thingino.com)
- [Dropbear SSH](https://matt.ucc.asn.au/dropbear/dropbear.html)
- [UnZip 6.0](https://sourceforge.net/projects/infozip/)
