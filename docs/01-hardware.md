# Hardware

## Specs

| Component | Model | Notes |
|-----------|-------|-------|
| Camera | MOES WCM-P52 | Tuya-based IP camera |
| SoC | Ingenic T31 | MIPS32 @ 1008MHz |
| Flash | XMC25QH64C | 64Mbit SPI NOR (8MB) |
| RAM | 64MB DDR | |
| WiFi | ATBM6012B-X | 802.11 b/g/n + BLE |
| Image Sensor | SC3336 | 3MP |
| OS | Linux 3.10.14 | |
| Userspace | BusyBox 1.22.1 | |
| SDK | TuyaOS 6.2.2 | |

---

## MTD Partition Layout

```
0x000000000000-0x000000040000 : "uboot"    (256KB)
0x000000040000-0x0000001b0000 : "kernel"   (1472KB)
0x0000001b0000-0x000000360000 : "rootfs"   (1728KB)
0x000000360000-0x000000430000 : "drv"      (832KB)
0x000000430000-0x0000005e0000 : "app"      (1728KB)
0x0000005e0000-0x000000790000 : "backup"   (1728KB)
0x000000790000-0x0000007e0000 : "data"     (320KB)
0x0000007e0000-0x000000800000 : "factory"  (128KB)
```

Total flash size: **8MB**

---

## UART

The camera exposes a UART header on the PCB.

**Settings:** 115200 baud, 8N1, no flow control

**Pinout:**
```
[ GND | TX | RX | VCC ]
```

> On macOS, always use `/dev/cu.usbserial-*` instead of `/dev/tty.usbserial-*`.
> The `cu` device opens immediately without waiting for the DCD signal.

**Connect:**
```bash
screen /dev/cu.usbserial-110 115200
```

---

## WiFi MAC Address

The WiFi MAC address is logged during boot and is visible in the UART output:

```
[atbm_log]:atbm_setup_mac:addr(80647cc8fae7)
```

Note your device's MAC before flashing a new firmware — you will need to set it manually in OpenIPC/Thingino.

---

## U-Boot

U-Boot version: `2013.07 (Dec 10 2024)`

> **Important:** U-Boot is compiled with `bootdelay=0`. The autoboot interrupt window is zero seconds, making it impossible to drop into the U-Boot shell via UART without hardware intervention (e.g. shorting the flash CS pin).

```
Hit any key to stop autoboot:  0
```
