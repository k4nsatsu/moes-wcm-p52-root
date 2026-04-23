# Firmware Analysis

## Obtaining the Original Firmware

The original firmware was found on GitHub. Always start your analysis from a known-good firmware image before dumping from the device itself.

---

## Extracting with binwalk

```bash
binwalk -e firmware.bin
```

The firmware contains multiple SquashFS partitions. Use `unsquashfs` for reliable extraction with XZ compression support:

```bash
unsquashfs -d ./rootfs_extracted rootfs.bin
unsquashfs -d ./app_extracted app.bin
```

---

## Key Scripts Discovered

After extraction, the following SD card-related scripts were found:

```
squashfs-root_app/skyeye/script/sdcard/automount.sh
squashfs-root_app/skyeye/script/sdcard/ty_sdcard_check_factory.sh
squashfs-root_app/skyeye/script/sdcard/ty_sdcard_check_upgrade.sh
squashfs-root_app/skyeye/script/upgrade/ty_sdcard_upgrade.sh
squashfs-root_app/skyeye/script/upgrade/ty_upgrade.sh
squashfs-root_app/skyeye/script/app/ty_monitor.sh
```

---

## The Vulnerability: automount.sh

The `automount.sh` script is triggered by `mdev` whenever an SD card is inserted. The critical section:

```sh
export LD_LIBRARY_PATH=/mnt/sdcard/:$LD_LIBRARY_PATH
cd /mnt/sdcard
./unzip -o ./t31.zip -d /tmp
chmod 777 /tmp/tuya -R
/tuya/app/skyeye/script/sdcard/ty_sdcard_check_factory.sh /tmp
```

Key observations:
- It calls `./unzip` **from the SD card itself** — you must provide this binary
- It extracts `t31.zip` into `/tmp`
- It calls `ty_sdcard_check_factory.sh` with `/tmp` as the argument
- **No signature or integrity verification at any point**

> Note: The `ty_sdcard_check_upgrade.sh` mechanism is commented out in the automount script and does not run.

---

## ty_sdcard_check_factory.sh

```sh
MNTDIR=$1
FACDIR=${MNTDIR}/tuya/fac

if [ ! -d ${FACDIR} ]; then
    echo "no factory dir, no need to check..."
    exit
fi

if [ -e ${FACDIR}/script/ty_auto_test.sh ]; then
    [ -x ${FACDIR}/script/ty_auto_test.sh ] && ${FACDIR}/script/ty_auto_test.sh
fi
```

This script executes `/tmp/tuya/fac/script/ty_auto_test.sh` — whatever you put there runs as root.

---

## Partition Analysis

### rootfs.bin
- Format: SquashFS 4.0, XZ compressed
- Contains the base Linux system, BusyBox, init scripts
- `/etc/shadow` contains the root password hash (md5crypt)
- BusyBox does **not** include the `unzip` applet — a static binary must be provided

### data.bin
- Format: JFFS2
- Contains runtime data: WiFi credentials, Tuya config, device certificates
- Extract with `jefferson`:
  ```bash
  pip3 install jefferson
  jefferson data.bin -d ./data_extracted
  ```
- Notable files:
  - `etc/shadow` — runtime shadow file
  - `wpa_0_8.conf` — saved WiFi credentials
  - `tuya_enckey.db` — Tuya encryption key (16 bytes AES-128)
  - `tuya_cfg.bin` — Tuya device configuration
  - `tuya_user.db` — Tuya user/device data

### backup.bin
- Contains TLS certificates and private keys for Tuya cloud authentication
- Device certificate uses **ECC P-256 (prime256v1)**
- Keep these files safe — they are unique to your device

### factory.bin
- Format: NVRAM (ASUS NVRAM v0.08)
- All values are **AES-128 encrypted and Base64 encoded**
- Contains: UUID, AUTHKEY, PID, SN, master_mac, ssid, pskkey
- The encryption key is fetched from the Tuya server at runtime — not stored locally in plaintext
- The WiFi MAC address can be recovered from the UART boot log instead
