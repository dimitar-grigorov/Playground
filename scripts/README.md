# Scripts

This directory contains various utility scripts for different tasks.

## Available Scripts

### 1. `strip_comments.py`

This Python script processes a Pascal source file to remove all lines starting with `//` or `///` (including leading spaces or tabs) and lines containing non-printable characters. The cleaned content is written to an output file. If only the input file is specified, the script automatically generates the output file name by appending `-stripped` to the input file name.

#### Usage

```bash
python strip_comments.py -i path/to/file.pas [-o path/to/file-stripped.pas]
```

- `-i`, `--input`: The path to the input file (mandatory).
- `-o`, `--output`: The path to the output file (optional). If not specified, the output file name is generated automatically.

### 2. `calculate_video_duration.sh`

This bash script calculates and displays the duration of each MP4 video file in the current directory and its subdirectories. It also calculates the total duration and prints it in the format HH:MM:SS. The script utilizes `ffprobe` to extract video durations and `bc` for arithmetic calculations.

#### Usage

Ensure that the `ffprobe` and `bc` commands are available on your system. Then, run the script in the directory containing your MP4 files:

```bash
./calculate_video_duration.sh
```

### 3. `sds011-monitor.py`

Interactive controller for the Nova Fitness SDS011 laser dust sensor. Reads PM2.5 and PM10 concentrations over serial (UART at 9600 baud) and classifies readings against WHO 2021 air quality thresholds (good / moderate / unhealthy / hazardous).

#### Requirements

```bash
pip install pyserial
```

#### Usage

```bash
python sds011-monitor.py [COM3 | /dev/ttyUSB0]
```

The port can be specified as `COM3` or just `3`. If omitted, the script will prompt for it.

#### Menu options

| # | Option | Description |
|---|--------|-------------|
| 1 | Measure once | Full cycle: wake -> 30 s warm-up -> read -> sleep |
| 2 | Optimal mode | Repeated measure cycles at a chosen interval (keeps fan off between readings) |
| 3 | Live | Continuous stream of readings, Ctrl+C to stop |
| 4 | Wake | Start the fan and laser |
| 5 | Query | Single reading (sensor must already be on) |
| 6 | Sleep | Stop the fan and laser |
| 7 | Firmware | Show the sensor firmware version |
| 8 | Working period | Configure hardware duty cycle (stored on sensor, survives power cycles) |

#### Notes

- The SDS011 laser diode has a rated lifespan of ~8000 operating hours. Use **Optimal mode** or **Working period** to duty-cycle the sensor and extend its life.
- Working period is a hardware setting: `0` = continuous, `1–30` = measure for 30 s then sleep for `(N × 60 − 30)` s. The setting persists after power-off.
- WHO 2021 thresholds used: PM2.5 — good ≤15, moderate ≤25, unhealthy ≤50, hazardous >50 µg/m³. PM10 — good ≤45, moderate ≤75, unhealthy ≤150, hazardous >150 µg/m³.

## Planned Scripts

- Additional file processing scripts.
- Data analysis and manipulation scripts.
- Automation scripts for system tasks.