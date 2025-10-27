#!/bin/bash

# Exit on Ctrl+C
trap 'echo ""; echo "Interrupted! Exiting..."; exit 130' INT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "Starting Docker container updates..."

for dir in */; do
    dir=${dir%/}
    [[ -d "$dir" ]] || continue

    echo "----------------------------------------"
    echo "Processing: $dir"

    cd "$dir" || continue

    # Check if compose file exists
    if [[ ! -f "docker-compose.yml" ]] && [[ ! -f "docker-compose.yaml" ]] && [[ ! -f "compose.yml" ]] && [[ ! -f "compose.yaml" ]]; then
        echo "No compose file found, skipping"
        cd "$SCRIPT_DIR"
        continue
    fi

    # Pull and check if new images were downloaded
    pull_output=$(sudo docker compose pull 2>&1)
    echo "$pull_output"

    if echo "$pull_output" | grep -qi "Downloading\|Downloaded\|digest.*sha256"; then
        echo "New images found, recreating containers..."
        sudo docker compose up --force-recreate --build -d
    else
        echo "No new images, skipping recreate"
    fi

    cd "$SCRIPT_DIR"
done

echo "----------------------------------------"
echo "Pruning unused images..."
sudo docker image prune -f

echo "Done!"