#!/bin/bash
# build-mips-binaries.sh
# Cross-compiles static MIPS binaries for the MOES WCM-P52 SD card payload.
# Requires: Docker, curl
# Usage: ./payload/build-mips-binaries.sh /Volumes/TUYA

set -e

SDCARD="${1:-/Volumes/TUYA}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[-]${NC} $1"; exit 1; }

# -------------------------------------------------------------------------
# Checks
# -------------------------------------------------------------------------

if [ ! -d "$SDCARD" ]; then
  error "SD card not found at $SDCARD. Mount it first or pass the path as argument."
fi

if ! command -v docker &>/dev/null; then
  error "Docker not found. Install Docker Desktop first."
fi

if ! command -v openssl &>/dev/null; then
  error "openssl not found."
fi

info "SD card: $SDCARD"
info "Starting build..."

# -------------------------------------------------------------------------
# Password hash
# -------------------------------------------------------------------------

echo ""
read -rsp "Enter desired root password: " ROOT_PASS
echo ""
read -rsp "Confirm password: " ROOT_PASS2
echo ""

if [ "$ROOT_PASS" != "$ROOT_PASS2" ]; then
  error "Passwords do not match."
fi

ROOT_HASH=$(openssl passwd -1 -salt "$(openssl rand -hex 4)" "$ROOT_PASS")
info "Password hash generated: $ROOT_HASH"

# -------------------------------------------------------------------------
# Download sources
# -------------------------------------------------------------------------

TMPDIR=$(mktemp -d)
info "Working directory: $TMPDIR"

info "Downloading UnZip 6.0..."
curl -sL 'https://sourceforge.net/projects/infozip/files/UnZip%206.x%20%28latest%29/UnZip%206.0/unzip60.tar.gz/download' \
  -o "$TMPDIR/unzip60.tar.gz"

info "Downloading Dropbear..."
curl -sL 'https://matt.ucc.asn.au/dropbear/releases/dropbear-2024.86.tar.bz2' \
  -o "$TMPDIR/dropbear.tar.bz2"

# -------------------------------------------------------------------------
# Compile via Docker
# -------------------------------------------------------------------------

info "Cross-compiling for MIPS (this may take a few minutes)..."

docker run --rm --platform linux/amd64 \
  -v "$SDCARD":/out \
  -v "$TMPDIR/unzip60.tar.gz":/unzip60.tar.gz \
  -v "$TMPDIR/dropbear.tar.bz2":/dropbear.tar.bz2 \
  debian:bullseye sh -c '
    set -e
    apt-get update -qq
    apt-get install -y -qq gcc-mipsel-linux-gnu make

    # ----- unzip -----
    echo "[build] compiling unzip..."
    tar xzf /unzip60.tar.gz
    cd unzip60
    make -f unix/Makefile CC="mipsel-linux-gnu-gcc -static" generic
    cp unzip /out/unzip
    echo "[build] unzip OK"
    cd /

    # ----- dropbear -----
    echo "[build] compiling dropbear..."
    tar xjf /dropbear.tar.bz2
    cd dropbear-*
    ./configure \
      --host=mipsel-linux-gnu \
      --disable-zlib \
      --disable-wtmp \
      --disable-lastlog \
      --disable-pam \
      CFLAGS="-static" LDFLAGS="-static" \
      > /dev/null 2>&1
    make PROGRAMS="dropbear dropbearkeygen" > /dev/null 2>&1
    cp dropbear dropbearkeygen /out/
    echo "[build] dropbear OK"
  '

info "Verifying binaries..."
file "$SDCARD/unzip"          | grep -q "MIPS" && info "  unzip:          OK" || error "unzip build failed"
file "$SDCARD/dropbear"       | grep -q "MIPS" && info "  dropbear:       OK" || error "dropbear build failed"
file "$SDCARD/dropbearkeygen" | grep -q "MIPS" && info "  dropbearkeygen: OK" || error "dropbearkeygen build failed"

# -------------------------------------------------------------------------
# Create payload zip
# -------------------------------------------------------------------------

info "Creating payload..."

PAYLOAD_DIR="$TMPDIR/t31payload/tuya/fac/script"
mkdir -p "$PAYLOAD_DIR"

cat > "$PAYLOAD_DIR/ty_auto_test.sh" << PAYLOAD
#!/bin/sh
echo "*****[payload]***** started" > /dev/console

SDCARD=/mnt/mmcblk0p1

/bin/busybox telnetd -l /bin/sh -p 23 > /dev/null 2>&1 &

cp \$SDCARD/dropbear /tmp/dropbear
cp \$SDCARD/dropbearkeygen /tmp/dropbearkeygen
chmod +x /tmp/dropbear /tmp/dropbearkeygen

mkdir -p /tmp/dropbear_keys
/tmp/dropbearkeygen -t rsa   -f /tmp/dropbear_keys/dropbear_rsa_host_key   > /dev/null 2>&1
/tmp/dropbearkeygen -t ecdsa -f /tmp/dropbear_keys/dropbear_ecdsa_host_key > /dev/null 2>&1

/tmp/dropbear \\
  -r /tmp/dropbear_keys/dropbear_rsa_host_key \\
  -r /tmp/dropbear_keys/dropbear_ecdsa_host_key \\
  -p 22 > /dev/null 2>&1 &

echo 'root:${ROOT_HASH}:10933:0:99999:7:::' > /etc/shadow

echo "*****[payload]***** done" > /dev/console
PAYLOAD

chmod +x "$PAYLOAD_DIR/ty_auto_test.sh"

cd "$TMPDIR/t31payload"
zip -r "$SDCARD/t31.zip" tuya/ > /dev/null

info "Verifying zip..."
unzip -l "$SDCARD/t31.zip" | grep -q "ty_auto_test.sh" && info "  t31.zip: OK" || error "zip creation failed"

# -------------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------------

echo ""
info "SD card is ready at $SDCARD"
echo ""
echo "  Contents:"
ls -lh "$SDCARD"/ | grep -v "^total\|^\." | awk '{print "    " $NF "\t" $5}'
echo ""
info "Eject the SD card and insert it into the powered-on camera."
info "Wait ~30 seconds, then connect:"
echo ""
echo "    ssh root@<CAMERA_IP>       password: $ROOT_PASS"
echo "    telnet <CAMERA_IP> 23      no password"
echo ""

# Cleanup
rm -rf "$TMPDIR"