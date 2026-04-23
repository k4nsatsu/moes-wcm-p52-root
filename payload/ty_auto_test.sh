#!/bin/sh
# ty_auto_test.sh — SD card payload for MOES WCM-P52 (Ingenic T31)
# Executed automatically by the camera's factory test mechanism on SD insertion.
# Runs as root with no interaction required.

echo "*****[payload]***** started" > /dev/console

SDCARD=/mnt/mmcblk0p1

# -------------------------------------------------------------------------
# Telnet — no password, instant shell access
# -------------------------------------------------------------------------
/bin/busybox telnetd -l /bin/sh -p 23 > /dev/null 2>&1 &

# -------------------------------------------------------------------------
# SSH via Dropbear
# Binaries are copied from SD card to RAM (/tmp) before execution
# -------------------------------------------------------------------------
cp $SDCARD/dropbear /tmp/dropbear
cp $SDCARD/dropbearkeygen /tmp/dropbearkeygen
chmod +x /tmp/dropbear /tmp/dropbearkeygen

mkdir -p /tmp/dropbear_keys
/tmp/dropbearkeygen -t rsa   -f /tmp/dropbear_keys/dropbear_rsa_host_key   > /dev/null 2>&1
/tmp/dropbearkeygen -t ecdsa -f /tmp/dropbear_keys/dropbear_ecdsa_host_key > /dev/null 2>&1

/tmp/dropbear \
  -r /tmp/dropbear_keys/dropbear_rsa_host_key \
  -r /tmp/dropbear_keys/dropbear_ecdsa_host_key \
  -p 22 > /dev/null 2>&1 &

# -------------------------------------------------------------------------
# Change root password
# Generate your hash with: openssl passwd -1 -salt Ab12Cd34 yourpassword
# Replace YOUR_HASH_HERE with the output
# -------------------------------------------------------------------------
echo 'root:YOUR_HASH_HERE:10933:0:99999:7:::' > /etc/shadow

echo "*****[payload]***** done" > /dev/console
