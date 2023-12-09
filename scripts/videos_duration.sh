#!/bin/bash

# This script calculates and displays the duration of each MP4 video file in the current directory and its subdirectories.
# It also calculates the total duration and prints it in the format HH:MM:SS.
# The script utilizes ffprobe to extract video durations and bc for arithmetic calculations.
# Note: Ensure that the ffprobe and bc commands are available on your system.

total_duration=0

while IFS= read -r -d '' file; do
    duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file")
    formatted_duration=$(awk -v dur="$duration" 'BEGIN { printf "%02d:%02d:%02d\n", int(dur/3600), int((dur%3600)/60), int(dur%60) }')
    printf "%s: %s\n" "$(basename "$file")" "$formatted_duration"

    # Accumulate total duration
    total_duration=$(echo "$total_duration + $duration" | bc)
done < <(find . -type f -name "*.mp4" -print0)

# Remove milliseconds from total duration
total_duration=$(echo "$total_duration/1" | bc)

# Print total duration
if [ "$total_duration" -gt 0 ]; then
    hours=$(echo "$total_duration/3600" | bc)
    minutes=$(echo "($total_duration%3600)/60" | bc)
    seconds=$(echo "$total_duration%60" | bc)

    printf "Total duration: %02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
else
    echo "No videos found."
fi