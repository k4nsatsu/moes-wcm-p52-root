# UART Access — Alternative Method

UART is not required to gain root access, but it is very useful for monitoring the boot process, debugging, and development.

---

## Why UART is Useful

- See real-time boot logs
- Confirm payload execution
- Interact with the shell directly without network access
- Useful if the camera has no IP yet (not connected to WiFi)

---

## Why You Cannot Interrupt U-Boot via UART

The U-Boot on this camera is compiled with `bootdelay=0`:

```
Hit any key to stop autoboot:  0
```

The interrupt window is zero seconds. Neither manual keypress nor automated scripts can intercept the boot sequence in time.

---

## Connecting

**Settings:** 115200 baud, 8N1, no flow control

```bash
# List available serial devices
ls /dev/cu.*

# Connect (replace with your device)
screen /dev/cu.usbserial-110 115200
```

> **macOS note:** Always use `/dev/cu.*` instead of `/dev/tty.*`.
> The `tty` device blocks waiting for DCD signal, which USB-UART adapters never assert.
> The `cu` device opens immediately.

---

## Reading the Boot Log

Power on the camera with UART connected. You will see the full boot sequence:

```
U-Boot SPL 2013.07 (Dec 10 2024)
...
Hit any key to stop autoboot:  0
...
Starting kernel ...
...
Tuya login:
```

---

## Login After Payload Execution

After inserting the SD card with the payload, watch for:

```
~~~~~~~~~~~~~~~~~~~ start to auto test...
*****[payload]***** started
*****[payload]***** done
```

Then press **Enter** at the `Tuya login:` prompt:

```
login: root
password: yourpassword
```

---

## Silencing Kernel Log Noise

The kernel continuously prints to the console, mixing with your shell output. Suppress it:

```bash
echo 0 > /proc/sys/kernel/printk
```

Restore with:

```bash
echo 7 > /proc/sys/kernel/printk
```
