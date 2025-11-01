#!/bin/bash
# remote-backup.sh - Backup remote servers via SSH to compressed archives

set -e

SOURCE_SERVER=""
SOURCE_DIR="/"
DEST_DIR="./backups"
BACKUP_NAME="backup"
EXCLUDES=("/dev/*" "/proc/*" "/sys/*" "/tmp/*" "/run/*" "/media/*" "/lost+found")

usage() {
    cat << EOF
Usage: $0 -s SERVER [OPTIONS]

Required:
    -s SERVER           Remote server (IP or hostname)

Options:
    -d DIR             Destination directory (default: ./backups)
    -n NAME            Backup name prefix (default: backup)
    -S DIR             Source directory on remote (default: /)
    -e PATTERN         Add exclude pattern (can be used multiple times)
    -h                 Show this help

Examples:
    $0 -s 192.168.1.100
    $0 -s myserver.com -n webserver -d /backups
    $0 -s 192.168.1.100 -e '/mnt/*' -e '/var/cache/*'

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s) SOURCE_SERVER="$2"; shift 2 ;;
        -d) DEST_DIR="$2"; shift 2 ;;
        -n) BACKUP_NAME="$2"; shift 2 ;;
        -S) SOURCE_DIR="$2"; shift 2 ;;
        -e) EXCLUDES+=("$2"); shift 2 ;;
        -h) usage ;;
        *) echo "Error: Unknown option $1"; usage ;;
    esac
done

[[ -z "$SOURCE_SERVER" ]] && { echo "Error: Server (-s) is required"; usage; }

# Check for compression tools
if command -v pigz &> /dev/null; then
    COMPRESS_CMD="pigz"
    echo "Using pigz for compression"
elif command -v gzip &> /dev/null; then
    COMPRESS_CMD="gzip"
    echo "Using gzip for compression"
else
    echo "Error: Neither pigz nor gzip found"
    exit 1
fi

mkdir -p "$DEST_DIR"

# Build exclude string
EXCLUDE_STRING=""
for pattern in "${EXCLUDES[@]}"; do
    EXCLUDE_STRING="$EXCLUDE_STRING --exclude='$pattern'"
done

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${DEST_DIR}/${BACKUP_NAME}-${TIMESTAMP}.tar.gz"

echo "Source: $SOURCE_SERVER:$SOURCE_DIR"
echo "Destination: $BACKUP_FILE"
echo "Starting backup..."

START_TIME=$(date +%s)

eval "ssh root@$SOURCE_SERVER \"tar $EXCLUDE_STRING -cf - $SOURCE_DIR\" | $COMPRESS_CMD > \"$BACKUP_FILE\""

if [[ $? -eq 0 ]]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    
    echo "Backup completed"
    echo "File: $(basename "$BACKUP_FILE")"
    echo "Size: $BACKUP_SIZE"
    echo "Time: ${DURATION}s"
else
    echo "Backup failed"
    rm -f "$BACKUP_FILE"
    exit 1
fi