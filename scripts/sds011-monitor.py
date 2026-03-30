#!/usr/bin/env python3
#
# SDS011 — particulate matter sensor controller
# Reads PM2.5 and PM10 values over serial (UART).
#
# Install:  pip install pyserial
#
# Usage:    python sds011-monitor.py [COM3 | /dev/ttyUSB0]
#           If no port is given, the script will prompt for one.

import serial
import time
import argparse


# ── Protocol constants ────────────────────────────────────────────────────────

def _build_cmd(cmd_id, d1=0, d2=0):
    """Assemble a 19-byte SDS011 command packet."""
    p = [0xAA, 0xB4, cmd_id, d1, d2] + [0] * 10 + [0xFF, 0xFF]
    p.append(sum(p[2:]) & 0xFF)  # checksum
    p.append(0xAB)               # tail
    return bytes(p)

CMD_SLEEP    = _build_cmd(0x06, 1, 0)
CMD_WAKE     = _build_cmd(0x06, 1, 1)
CMD_ACTIVE   = _build_cmd(0x02, 1, 0)  # continuous reporting mode
CMD_FIRMWARE = _build_cmd(0x07, 0, 0)  # GET firmware version
CMD_GET_PERIOD = _build_cmd(0x08, 0, 0)  # GET working period


# ── Serial helpers ────────────────────────────────────────────────────────────

def _send(ser, cmd):
    ser.write(cmd)
    time.sleep(0.15)

def _read_packet(ser, timeout=4.0, expect=0xC0):
    """Read the next valid 10-byte packet of the expected type.

    expect=0xC0 for measurement data, 0xC5 for config/command replies.
    Skips packets of other types rather than returning them by mistake.
    """
    ser.timeout = timeout
    deadline = time.time() + timeout
    buf = b""
    while time.time() < deadline:
        byte = ser.read(1)
        if not byte:
            continue
        buf += byte
        if len(buf) == 1 and buf[0] != 0xAA:
            buf = b""
            continue
        if len(buf) == 2 and buf[1] not in (0xC0, 0xC5):
            buf = b""
            continue
        if len(buf) == 10:
            if buf[1] == expect:
                return buf
            buf = b""  # right length but wrong type — keep looking
        elif len(buf) > 10:
            buf = b""
    return None

def _decode(pkt):
    """Parse a raw 10-byte packet into (PM2.5, PM10) in µg/m³."""
    if not pkt or len(pkt) < 10:
        return None
    if pkt[0] != 0xAA or pkt[1] != 0xC0 or pkt[9] != 0xAB:
        return None
    if (sum(pkt[2:8]) & 0xFF) != pkt[8]:
        print("  [!] Checksum mismatch — packet discarded")
        return None
    pm25 = (pkt[3] * 256 + pkt[2]) / 10.0
    pm10 = (pkt[5] * 256 + pkt[4]) / 10.0
    return pm25, pm10


# ── Display ───────────────────────────────────────────────────────────────────

# WHO 2021 air quality thresholds (µg/m³)
#   PM2.5:  0–15 good,  15–25 moderate,  25–50 unhealthy,  >50 hazardous
#   PM10:   0–45 good,  45–75 moderate,  75–150 unhealthy, >150 hazardous
def _label_pm25(v):
    if v <= 15:  return "good"
    if v <= 25:  return "moderate"
    if v <= 50:  return "unhealthy"
    return           "hazardous"

def _label_pm10(v):
    if v <= 45:  return "good"
    if v <= 75:  return "moderate"
    if v <= 150: return "unhealthy"
    return           "hazardous"

def _format_reading(pm25, pm10):
    return (
        f"  PM2.5: {pm25:6.1f} ug/m3  ({_label_pm25(pm25)})  "
        f"PM10:  {pm10:6.1f} ug/m3  ({_label_pm10(pm10)})"
    )


# ── Actions ───────────────────────────────────────────────────────────────────

def do_sleep(ser):
    _send(ser, CMD_SLEEP)
    print("  Fan stopped.")

def do_wake(ser):
    _send(ser, CMD_WAKE)
    _send(ser, CMD_ACTIVE)
    print("  Warming up for 30 s...")
    for remaining in range(30, 0, -5):
        print(f"  ...{remaining}s")
        time.sleep(5)

def do_query(ser):
    """Take a single reading from the active stream."""
    _send(ser, CMD_ACTIVE)
    ser.reset_input_buffer()
    time.sleep(1.2)  # let the sensor emit a fresh packet
    pkt = _read_packet(ser)
    result = _decode(pkt)
    if result:
        print(_format_reading(*result))
        print(f"  Raw: {pkt.hex(' ').upper()}")
    else:
        print("  No valid response — is the sensor asleep?")

def do_live(ser):
    """Stream continuous readings until Ctrl+C."""
    _send(ser, CMD_ACTIVE)
    print("  Live mode — press Ctrl+C to stop\n")
    try:
        while True:
            result = _decode(_read_packet(ser, timeout=3.0))
            if result:
                ts = time.strftime("%H:%M:%S")
                print(f"  [{ts}]  {_format_reading(*result)}")
    except KeyboardInterrupt:
        print("\n  Stopped.")

def do_measure(ser):
    """Full cycle: wake sensor -> warm up -> read -> sleep."""
    do_wake(ser)
    do_query(ser)
    do_sleep(ser)

def do_optimal(ser):
    """Repeated measure cycle at a set interval (Ctrl+C to stop).

    Each cycle: wake -> 30s warm-up -> read -> sleep -> wait.
    Keeps the fan off between readings to extend sensor lifespan.
    """
    raw = input("  Interval between readings in minutes [5]: ").strip()
    interval = int(raw) if raw.isdigit() and int(raw) > 0 else 5
    print(f"  Measuring every {interval} min — Ctrl+C to stop\n")

    try:
        while True:
            do_wake(ser)
            do_query(ser)
            do_sleep(ser)
            print(f"  Next reading in {interval} min...")
            time.sleep(interval * 60)
    except KeyboardInterrupt:
        do_sleep(ser)
        print("\n  Stopped.")

def do_firmware(ser):
    """Read firmware version from the sensor."""
    _send(ser, CMD_WAKE)
    time.sleep(0.5)
    ser.reset_input_buffer()
    _send(ser, CMD_FIRMWARE)
    time.sleep(0.1)  # give sensor time to reply before we start reading
    pkt = _read_packet(ser, expect=0xC5)
    print(f"  Raw: {pkt.hex(' ').upper() if pkt else 'None'}")
    if pkt and pkt[0] == 0xAA and pkt[1] == 0xC5:
        yy, mm, dd = pkt[3], pkt[4], pkt[5]
        print(f"  Firmware: 20{yy:02d}-{mm:02d}-{dd:02d}")
    else:
        print("  No response.")

def do_working_period(ser):
    """Show and optionally change the duty-cycle working period.

    Period 0  = continuous (every second, factory default).
    Period N  = 30 s on, then sleep for (N*60 - 30) s, then repeat.
    Extends laser lifespan significantly (rated ~8000 operating hours).
    The setting survives power cycles.
    """
    _send(ser, CMD_WAKE)
    time.sleep(0.5)
    ser.reset_input_buffer()
    _send(ser, CMD_GET_PERIOD)
    time.sleep(0.1)
    pkt = _read_packet(ser, expect=0xC5)
    print(f"  Raw: {pkt.hex(' ').upper() if pkt else 'None'}")
    if not pkt or pkt[1] != 0xC5:
        print("  No response.")
        return

    current = pkt[4]
    if current == 0:
        print(f"  Working period: continuous (every second)")
    else:
        on_s  = 30
        off_s = current * 60 - 30
        print(f"  Working period: {current} min  (30 s on / {off_s} s off)")

    print()
    raw = input("  New period (0 = continuous, 1-30 min, Enter to keep): ").strip()
    if not raw:
        return
    if not raw.isdigit() or not (0 <= int(raw) <= 30):
        print("  Invalid value.")
        return
    n = int(raw)
    if n == 0:
        print("  Sensor will measure continuously every second.")
    else:
        off_s = n * 60 - 30
        off_str = f"{off_s // 60} min {off_s % 60} s" if off_s >= 60 else f"{off_s} s"
        print(f"  Sensor will measure for 30 s, then sleep for {off_str}, then repeat.")
        print(f"  Setting is saved on the sensor and survives power cycles.")
    _send(ser, _build_cmd(0x08, 1, n))
    pkt = _read_packet(ser, expect=0xC5)
    if pkt and pkt[1] == 0xC5:
        print(f"  Done.")
    else:
        print("  Command sent, no confirmation received.")


# ── Menu ──────────────────────────────────────────────────────────────────────

MENU = [
    ("Measure once    (wake -> 30s warm-up -> read -> sleep)", do_measure),
    ("Optimal mode    (repeated cycles at set interval)",      do_optimal),
    ("Live            (continuous readings, Ctrl+C to stop)",  do_live),
    ("Wake            (start fan)",                            do_wake),
    ("Query           (single reading, sensor must be on)",    do_query),
    ("Sleep           (stop fan)",                             do_sleep),
    ("Firmware        (show sensor firmware version)",         do_firmware),
    ("Working period  (duty cycle to extend sensor lifespan)", do_working_period),
]

def main():
    ap = argparse.ArgumentParser(description="SDS011 particulate matter sensor controller")
    ap.add_argument("port", nargs="?", help="Serial port, e.g. COM3 or /dev/ttyUSB0")
    args = ap.parse_args()

    raw_port = args.port or input("COM port (e.g. COM3 or 3): ").strip()
    port = f"COM{raw_port}" if raw_port.isdigit() else raw_port
    try:
        ser = serial.Serial(port, 9600, timeout=2)
        print(f"  Opened {port} @ 9600 baud\n")
    except Exception as e:
        print(f"  Error: {e}")
        return

    while True:
        print("\n" + "─" * 54)
        for i, (label, _) in enumerate(MENU, 1):
            print(f"  {i}. {label}")
        print("  0. Exit")
        print("─" * 54)
        choice = input("Choice: ").strip()
        if choice == "0":
            break
        if choice.isdigit() and 1 <= int(choice) <= len(MENU):
            print()
            MENU[int(choice) - 1][1](ser)
        else:
            print("  Invalid choice.")

    ser.close()


if __name__ == "__main__":
    main()
