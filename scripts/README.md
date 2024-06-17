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

## Planned Scripts

- Additional file processing scripts.
- Data analysis and manipulation scripts.
- Automation scripts for system tasks.