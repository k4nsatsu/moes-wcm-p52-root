# SD Card Payload — Root Access

This is the primary method. A UART adapter is recommended to monitor execution, but the payload itself runs automatically on SD insertion.

---

## Requirements

- SD card (any size)
- Docker Desktop
- macOS or Linux
- USB-UART adapter (recommended, for monitoring)

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

## Step 2 — Build and Prepare the SD Card

Run the build script — it compiles a static MIPS `unzip` binary, generates your password hash, and packs everything into the correct structure:

```bash
./payload/build-mips-binaries.sh /Volumes/TUYA
```

The script will ask for a root password and handle everything else.

Alternatively, do it manually:

### Manual setup

```bash
# Generate root password hash
openssl passwd -1 -salt Ab12Cd34 yourpassword
# Output example: $1$Ab12Cd34$H4AITkzmvn77bWgKa4M.k/

# Download and compile unzip for MIPS
curl -L 'https://sourceforge.net/projects/infozip/files/UnZip%206.x%20%28latest%29/UnZip%206.0/unzip60.tar.gz/download' \
  -o /tmp/unzip60.tar.gz

docker run --rm --platform linux/amd64 \
  -v /Volumes/TUYA:/out \
  -v /tmp/unzip60.tar.gz:/unzip60.tar.gz \
  debian:bullseye sh -c "
    apt-get update -qq &&
    apt-get install -y -qq gcc-mipsel-linux-gnu make &&
    tar xzf /unzip60.tar.gz &&
    cd unzip60 &&
    make -f unix/Makefile CC='mipsel-linux-gnu-gcc -static' generic &&
    cp unzip /out/unzip
  "

# Create payload structure
mkdir -p /tmp/t31payload/tuya/fac/script

cat > /tmp/t31payload/tuya/fac/script/ty_auto_test.sh << 'PAYLOAD'
#!/bin/sh
echo "*****[payload]***** started" > /dev/console
echo 'root:YOUR_HASH_HERE:10933:0:99999:7:::' > /etc/shadow
echo "*****[payload]***** done" > /dev/console
PAYLOAD

chmod +x /tmp/t31payload/tuya/fac/script/ty_auto_test.sh

# Pack into zip
cd /tmp/t31payload
zip -r /Volumes/TUYA/t31.zip tuya/

# Verify
unzip -l /Volumes/TUYA/t31.zip
```

---

## Step 3 — Verify SD Card Contents

```bash
ls -lh /Volumes/TUYA/
```

Expected:

```
unzip      ← static MIPS binary
t31.zip    ← payload zip
```

---

## Step 4 — Execute

1. Eject the SD card safely:

   ```bash
   diskutil eject /dev/diskN
   ```

2. Power on the camera and wait for it to fully boot (~15 seconds)

3. Insert the SD card

4. Watch the UART log for confirmation:

   ```
   ~~~~~~~~~~~~~~~~~~~ start to auto test...
   *****[payload]***** started
   *****[payload]***** done
   ```

5. Press **Enter** at the `Tuya login:` prompt on UART:
   ```
   login: root
   password: yourpassword
   ```

---

## Troubleshooting

| Symptom                            | Cause                   | Fix                                                           |
| ---------------------------------- | ----------------------- | ------------------------------------------------------------- |
| `[EXFAT] trying to mount... Fail`  | Wrong SD format         | Reformat as FAT32 MBR                                         |
| `no factory dir` in UART log       | `unzip` failed silently | Ensure `unzip` is a valid static MIPS binary in SD root       |
| `no auto test script` in UART log  | Wrong zip structure     | Verify zip contains `tuya/fac/script/ty_auto_test.sh` exactly |
| Login still rejected after payload | Hash format issue       | Regenerate hash with `openssl passwd -1`                      |

---

## Notes

- The payload runs every time the SD card is inserted while the camera is on
- Changes to `/etc/shadow` persist across reboots as the `data` partition is writable
- UART access is the confirmed working method — network access (SSH/Telnet) is planned but not yet tested
