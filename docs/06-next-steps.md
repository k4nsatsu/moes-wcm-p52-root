# Next Steps — Flashing OpenIPC or Thingino

> ⚠️ **Work in progress.** Root access has been achieved and the firmware has been fully backed up. The firmware replacement process has not been completed or verified yet. This document outlines the planned approach — follow at your own risk and always keep a full backup.

---

## Candidates

### Thingino

[Thingino](https://thingino.com) has specific support for the Ingenic T31 SoC and is actively developed with a focus on IP cameras.

- Check the [Thingino device list](https://github.com/themactep/thingino-firmware) for T31 support
- Join the [Thingino discussions](https://github.com/themactep/thingino-firmware/discussions)

### OpenIPC

[OpenIPC](https://openipc.org/cameras/vendors/ingenic/socs/t31) also supports the Ingenic T31 SoC.

---

## Before Attempting to Flash

1. **Complete firmware backup is mandatory** — see [Firmware Backup](05-firmware-backup.md)

2. **Note your WiFi MAC address** — from the UART boot log:

   ```
   [atbm_log]:atbm_setup_mac:addr(80647cc8fae7)
   ```

   You will need to set this manually in the new firmware.

3. **Keep UART connected** — essential for recovery if the new firmware fails to boot.

---

## Planned Approach

```bash
# Flash individual partitions from root shell
mtd write kernel.bin kernel
mtd write rootfs.bin rootfs
```

---

## Recovery

If the camera fails to boot after flashing:

**Option 1 — Flash CS short circuit** (hardware)
Briefly short the CS# pin (pin 1) of the XMC25QH64C flash chip to GND during power-on to force a U-Boot recovery prompt.

**Option 2 — External programmer**
Clip or desolder the XMC25QH64C and reflash `firmware_original_complete.bin` using a CH341 programmer with the camera powered off.

---

## Status

- [x] Root access achieved via SD card payload
- [x] Full firmware backup completed
- [ ] Network access via SSH (Dropbear static MIPS binary — planned)
- [ ] Network access via Telnet (BusyBox telnetd — planned)
- [ ] OpenIPC/Thingino build for this hardware
- [ ] Verified flash procedure
- [ ] Confirmed working after flash
