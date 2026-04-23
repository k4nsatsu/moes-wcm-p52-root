# Firmware Backup

**Always back up all partitions before flashing any new firmware.** This is your only recovery option if something goes wrong.

---

## Dumping All Partitions

With root shell obtained (via SSH, Telnet, or UART), run the following with an SD card inserted:

```bash
# Silence kernel log for cleaner output (optional)
echo 0 > /proc/sys/kernel/printk

# Dump all partitions to the SD card
dd if=/dev/mtdblock0 of=/mnt/mmcblk0p1/uboot.bin
dd if=/dev/mtdblock1 of=/mnt/mmcblk0p1/kernel.bin
dd if=/dev/mtdblock2 of=/mnt/mmcblk0p1/rootfs.bin
dd if=/dev/mtdblock3 of=/mnt/mmcblk0p1/drv.bin
dd if=/dev/mtdblock4 of=/mnt/mmcblk0p1/app.bin
dd if=/dev/mtdblock5 of=/mnt/mmcblk0p1/backup.bin
dd if=/dev/mtdblock6 of=/mnt/mmcblk0p1/data.bin
dd if=/dev/mtdblock7 of=/mnt/mmcblk0p1/factory.bin

# Verify
ls -lh /mnt/mmcblk0p1/*.bin
```

Expected output:
```
uboot.bin     256.0K
kernel.bin      1.4M
rootfs.bin      1.7M
drv.bin       832.0K
app.bin         1.7M
backup.bin      1.7M
data.bin      320.0K
factory.bin   128.0K
```

---

## Reassembling the Full Firmware Image

The partitions can be concatenated back into a single 8MB image for flashing via a programmer:

```bash
cat uboot.bin \
    kernel.bin \
    rootfs.bin \
    drv.bin \
    app.bin \
    backup.bin \
    data.bin \
    factory.bin \
    > firmware_original_complete.bin

# Verify total size — must be exactly 8MB
ls -lh firmware_original_complete.bin
du -b firmware_original_complete.bin
# Expected: 8388608 bytes
```

---

## Important Data to Record Before Flashing

Before installing any new firmware, note the following:

**WiFi MAC Address** — visible in UART boot log:
```
[atbm_log]:atbm_setup_mac:addr(80647cc8fae7)
```
You will need to configure this manually in OpenIPC/Thingino.

**TLS Certificates** — located in `backup.bin`:
```
pem.crt   ← device certificate (ECC P-256)
pem.key   ← private key
```
Store these securely. Do not publish them.

---

## Analyzing the Partitions

### rootfs.bin — SquashFS

```bash
unsquashfs -d ./rootfs_extracted rootfs.bin
```

### data.bin — JFFS2

```bash
pip3 install jefferson
jefferson data.bin -d ./data_extracted
```

Notable files in `data_extracted/`:
```
etc/shadow              ← runtime root password
wpa_0_8.conf            ← saved WiFi credentials (plaintext)
tuya_enckey.db          ← AES-128 encryption key (16 bytes)
tuya_cfg.bin            ← Tuya device configuration
tuya_user.db            ← Tuya user/device binding data
```

### backup.bin — Mixed

```bash
binwalk -e backup.bin
# Contains TLS certificates and private keys
```

### factory.bin — NVRAM

```bash
strings factory.bin
```

All values are AES-128 encrypted and Base64 encoded. The encryption key is retrieved from the Tuya server at runtime. Use the UART boot log to recover the WiFi MAC address instead.
