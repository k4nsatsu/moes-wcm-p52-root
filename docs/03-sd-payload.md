# SD Card Payload — Root Access (No UART Required)

This is the primary method. No UART adapter needed — just an SD card and Docker.

---

## Requirements

- SD card (any size)
- Docker Desktop
- macOS or Linux

---

## Step 1 — Format the SD Card

The camera requires **FAT32 with MBR partitioning**. exFAT and GPT will fail silently.

```bash
# Identify your SD card disk (e.g. disk4)
diskutil list

# Format as FAT32 MBR (replace diskN)
diskutil eraseDisk MS-DOS TUYA MBRFormat /dev/diskN

# Verify — must show FDisk_partition_scheme and DOS_FAT_32
diskutil list /dev/diskN
```

Expected output:
```
/dev/diskN (external, physical):
   #:  TYPE                NAME    SIZE
   0:  FDisk_partition_scheme      *31.9 GB
   1:  DOS_FAT_32          TUYA    31.9 GB
```

---

## Step 2 — Build MIPS Binaries

The automount script calls `./unzip` from the SD root. Since the camera's BusyBox lacks this applet, a static MIPS binary must be compiled and placed on the SD.

The build script handles everything:

```bash
./payload/build-mips-binaries.sh /Volumes/TUYA
```

This compiles and copies to the SD:
- `unzip` — static MIPS binary for extracting the payload
- `dropbear` — lightweight SSH server
- `dropbearkeygen` — SSH key generator

---

## Step 3 — Generate a Root Password Hash

```bash
openssl passwd -1 -salt Ab12Cd34 yourpassword
# Output: $1$Ab12Cd34$xxxxxxxxxxxxxxxxxxxx
```

---

## Step 4 — Create the Payload

```bash
# Create the directory structure
mkdir -p /tmp/t31payload/tuya/fac/script

# Create the payload script
cat > /tmp/t31payload/tuya/fac/script/ty_auto_test.sh << 'EOF'
#!/bin/sh
echo "*****[payload]***** started" > /dev/console

SDCARD=/mnt/mmcblk0p1

# --- Telnet (busybox, no password) ---
/bin/busybox telnetd -l /bin/sh -p 23 > /dev/null 2>&1 &

# --- SSH (dropbear) ---
cp $SDCARD/dropbear /tmp/dropbear
cp $SDCARD/dropbearkeygen /tmp/dropbearkeygen
chmod +x /tmp/dropbear /tmp/dropbearkeygen

mkdir -p /tmp/dropbear_keys
/tmp/dropbearkeygen -t rsa -f /tmp/dropbear_keys/dropbear_rsa_host_key
/tmp/dropbearkeygen -t ecdsa -f /tmp/dropbear_keys/dropbear_ecdsa_host_key

/tmp/dropbear \
  -r /tmp/dropbear_keys/dropbear_rsa_host_key \
  -r /tmp/dropbear_keys/dropbear_ecdsa_host_key \
  -p 22 &

# --- Change root password ---
# Replace the hash below with your own (generated with: openssl passwd -1 -salt Ab12Cd34 yourpassword)
echo 'root:YOUR_HASH_HERE:10933:0:99999:7:::' > /etc/shadow

echo "*****[payload]***** done" > /dev/console
EOF

chmod +x /tmp/t31payload/tuya/fac/script/ty_auto_test.sh

# Pack into zip
cd /tmp/t31payload
zip -r /Volumes/TUYA/t31.zip tuya/

# Verify zip contents
unzip -l /Volumes/TUYA/t31.zip
```

Expected zip contents:
```
tuya/fac/script/ty_auto_test.sh
```

---

## Step 5 — Verify SD Card Contents

```bash
ls -lh /Volumes/TUYA/
```

Expected:
```
unzip             ← static MIPS binary
dropbear          ← SSH server
dropbearkeygen    ← SSH key generator
t31.zip           ← payload zip
```

---

## Step 6 — Execute

1. Eject the SD card safely:
   ```bash
   diskutil eject /dev/diskN
   ```

2. Power on the camera and **wait for it to fully boot** (~15 seconds)

3. Insert the SD card

4. Wait ~30 seconds for the payload to execute

5. Connect:
   ```bash
   # SSH (recommended)
   ssh root@<CAMERA_IP>

   # Telnet (no password required)
   telnet <CAMERA_IP> 23
   ```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| SSH/Telnet connection refused | Payload didn't run | Check SD format (must be FAT32 MBR) |
| `[EXFAT] trying to mount... Fail` | Wrong SD format | Reformat as FAT32 MBR |
| `no factory dir` in UART log | `unzip` failed | Ensure `unzip` is a valid static MIPS binary |
| `no auto test script` in UART log | Wrong zip structure | Verify zip contains `tuya/fac/script/ty_auto_test.sh` |
| SSH host key warning | New keys generated each boot | Use `ssh -o StrictHostKeyChecking=no root@<IP>` |

---

## Notes

- The payload runs **every time** the SD card is inserted while the camera is on
- SSH and Telnet services run **in RAM only** — they stop when the camera reboots
- To make changes permanent, modify the filesystem directly after gaining access
- The `data` partition is writable — a good place to add persistent startup scripts
