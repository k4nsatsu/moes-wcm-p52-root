#!/bin/sh
# ty_auto_test.sh — SD card payload for MOES WCM-P52 (Ingenic T31)
# Executed automatically by the camera's factory test mechanism on SD insertion.
# Runs as root with no interaction required.
#
# Confirmed working: changes root password, allowing login via UART console.

echo "*****[payload]***** started" > /dev/console

# -------------------------------------------------------------------------
# Change root password
# Generate your hash with: openssl passwd -1 -salt Ab12Cd34 yourpassword
# Replace YOUR_HASH_HERE with the output
# -------------------------------------------------------------------------
echo 'root:YOUR_HASH_HERE:10933:0:99999:7:::' > /etc/shadow

echo "*****[payload]***** done" > /dev/console
