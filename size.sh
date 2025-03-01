#!/bin/bash

directories=(
    "$HOME/Library/Caches Application Caches"
    "$HOME/Library/Developer/Xcode/DerivedData Xcode Derived Data"
    "$HOME/Library/Developer/CoreSimulator Xcode Simulator Data"
    "$HOME/Library/Android/sdk Android SDK"
    "$HOME/Library/Application Support Application Support"
    "/private/var/log System Logs"
    "/private/var/folders Temporary Files"
)

LOG_FILE="$HOME/storage_report.txt"

echo "📊 Storage Usage Report - $(date)" | tee "$LOG_FILE"
echo "-----------------------------------" | tee -a "$LOG_FILE"

for entry in "${directories[@]}"; do
    dir=$(echo "$entry" | awk '{print $1}')
    name=$(echo "$entry" | cut -d' ' -f2-)

    if [ -d "$dir" ]; then
        size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
        echo "$name: $size" | tee -a "$LOG_FILE"
    else
        echo "$name: Not Found" | tee -a "$LOG_FILE"
    fi
done

echo "📂 Full report saved in: $LOG_FILE"
