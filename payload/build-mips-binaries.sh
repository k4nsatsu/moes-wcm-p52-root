#!/bin/bash
# build-mips-binaries.sh
# Cross-compiles a static MIPS unzip binary and prepares the SD card payload.
# Confirmed working on MOES WCM-P52 (Ingenic T31).
#
# Requirements: Docker, curl, openssl
# Usage: ./payload/build-mips-binaries.sh /Volumes/TUYA

set -e

SDCARD="${1:-/Volumes/TUYA}"

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

[ ! -d "$SDCARD" ] && error "SD card not found at $SDCARD"
command -v docker  &>/dev/null || error "Docker not found. Install Docker Desktop first."
command -v openssl &>/dev/null || error "openssl not found."

info "SD card: $SDCARD"

# -------------------------------------------------------------------------
# Password hash
# -------------------------------------------------------------------------

echo ""
read -rsp "Enter desired root password: " ROOT_PASS
echo ""
read -rsp "Confirm password: " ROOT_PASS2
echo ""

[ "$ROOT_PASS" != "$ROOT_PASS2" ] && error "Passwords do not match."

SALT=$(openssl rand -hex 4)
ROOT_HASH=$(openssl passwd -1 -salt "$SALT" "$ROOT_PASS")
info "Password hash: $ROOT_HASH"

# -------------------------------------------------------------------------
# Download unzip source
# -------------------------------------------------------------------------

TMPDIR=$(mktemp -d)
info "Working directory: $TMPDIR"

info "Downloading UnZip 6.0..."
curl -sL 'https://sourceforge.net/projects/infozip/files/UnZip%206.x%20%28latest%29/UnZip%206.0/unzip60.tar.gz/download' \
  -o "$TMPDIR/unzip60.tar.gz"

# -------------------------------------------------------------------------
# Cross-compile unzip for MIPS via Docker
# -------------------------------------------------------------------------

info "Cross-compiling unzip for MIPS..."

docker run --rm --platform linux/amd64 \
  -v "$SDCARD":/out \
  -v "$TMPDIR/unzip60.tar.gz":/unzip60.tar.gz \
  debian:bullseye sh -c '
    set -e
    apt-get update -qq
    apt-get install -y -qq gcc-mipsel-linux-gnu make
    tar xzf /unzip60.tar.gz
    cd unzip60
    make -f unix/Makefile CC="mipsel-linux-gnu-gcc -static" generic
    cp unzip /out/unzip
    echo "[build] unzip OK"
  '

file "$SDCARD/unzip" | grep -q "MIPS" && info "unzip: OK" || error "unzip build failed"

# -------------------------------------------------------------------------
# Create payload zip
# -------------------------------------------------------------------------

info "Creating payload..."

PAYLOAD_DIR="$TMPDIR/t31payload/tuya/fac/script"
mkdir -p "$PAYLOAD_DIR"

cat > "$PAYLOAD_DIR/ty_auto_test.sh" << PAYLOAD
#!/bin/sh
echo "*****[payload]***** started" > /dev/console

echo 'root:${ROOT_HASH}:10933:0:99999:7:::' > /etc/shadow

echo "*****[payload]***** done" > /dev/console
PAYLOAD

chmod +x "$PAYLOAD_DIR/ty_auto_test.sh"

cd "$TMPDIR/t31payload"
zip -r "$SDCARD/t31.zip" tuya/ > /dev/null

unzip -l "$SDCARD/t31.zip" | grep -q "ty_auto_test.sh" && info "t31.zip: OK" || error "zip creation failed"

# -------------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------------

echo ""
info "SD card is ready at $SDCARD"
echo ""
echo "  Contents:"
ls -lh "$SDCARD"/ | grep -v "^total\|^\." | awk '{print "    " $NF "\t" $5}'
echo ""
info "Eject the SD card, insert it into the powered-on camera and wait ~30s."
info "Then login via UART:"
echo ""
echo "    login: root"
echo "    password: $ROOT_PASS"
echo ""

rm -rf "$TMPDIR"