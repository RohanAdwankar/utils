#!/bin/bash

# Function to display usage instructions
usage() {
    echo "Usage: $0 [options] <input_file> <target_duration>"
    echo ""
    echo "Options:"
    echo "  -o, --output FILE    Specify output filename (default: inputfile_adjusted.ext)"
    echo "  -d, --dry-run        Show what would happen without processing"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Target duration formats:"
    echo "  MM:SS               Minutes and seconds (e.g., 02:30)"
    echo "  HH:MM:SS            Hours, minutes and seconds (e.g., 01:02:30)"
    echo "  seconds             Just total seconds (e.g., 150)"
    exit 1
}

# Check for required tools
check_dependencies() {
    for cmd in ffmpeg ffprobe bc; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required command '$cmd' not found. Please install it first."
            exit 1
        fi
    done
}

# Parse target duration to seconds
parse_duration() {
    local duration="$1"
    local total_seconds=0
    
    # Check if format is just seconds
    if [[ "$duration" =~ ^[0-9]+$ ]]; then
        total_seconds="$duration"
    # Check if format is MM:SS
    elif [[ "$duration" =~ ^[0-9]+:[0-9]{2}$ ]]; then
        minutes=$(echo "$duration" | cut -d':' -f1)
        seconds=$(echo "$duration" | cut -d':' -f2)
        total_seconds=$((minutes * 60 + seconds))
    # Check if format is HH:MM:SS
    elif [[ "$duration" =~ ^[0-9]+:[0-9]{2}:[0-9]{2}$ ]]; then
        hours=$(echo "$duration" | cut -d':' -f1)
        minutes=$(echo "$duration" | cut -d':' -f2)
        seconds=$(echo "$duration" | cut -d':' -f3)
        total_seconds=$(( hours * 3600 + minutes * 60 + seconds))
    else
        echo "Error: Invalid duration format. Use MM:SS, HH:MM:SS or seconds."
        exit 1
    fi
    
    echo "$total_seconds"
}

# Format seconds to HH:MM:SS
format_duration() {
    local seconds="$1"
    printf "%02d:%02d:%02d" $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
}

# Initialize variables
output_file=""
dry_run=0

# Process options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        -d|--dry-run)
            dry_run=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Check dependencies
check_dependencies

# Check if the correct number of arguments is provided
if [ $# -ne 2 ]; then
    usage
fi

input_file="$1"
target_duration="$2"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found."
    exit 1
fi

# Generate the output file name if not specified
if [ -z "$output_file" ]; then
    output_file="${input_file%.*}_adjusted.${input_file##*.}"
fi

# Convert target duration to total seconds
target_total_seconds=$(parse_duration "$target_duration")

# Get the original duration of the video in seconds
original_duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of csv=p=0 "$input_file")
original_duration=${original_duration%.*} # Remove fractional part

if [ -z "$original_duration" ]; then
    echo "Error: Could not determine video duration. Is this a valid video file?"
    exit 1
fi

# Calculate the speed factor
speed_factor=$(echo "scale=6; $original_duration / $target_total_seconds" | bc)

# Determine the appropriate atempo filter values
atempo_filters=""
remaining_speed=$speed_factor
while (( $(echo "$remaining_speed > 2.0" | bc -l) )); do
    atempo_filters+="atempo=2.0,"
    remaining_speed=$(echo "scale=6; $remaining_speed / 2.0" | bc)
done
while (( $(echo "$remaining_speed < 0.5" | bc -l) )); do
    atempo_filters+="atempo=0.5,"
    remaining_speed=$(echo "scale=6; $remaining_speed * 2.0" | bc)
done
atempo_filters+="atempo=$remaining_speed"

# Display information
echo "Original duration: $(format_duration $original_duration)"
echo "Target duration: $(format_duration $target_total_seconds)"
echo "Speed factor: ${speed_factor}x"

# Check if the input file has an audio stream
audio_stream=$(ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 "$input_file")

# Check if dry run only
if [ $dry_run -eq 1 ]; then
    echo "[DRY RUN] Would save output to: $output_file"
    exit 0
fi

echo "Processing video..."

if [ -z "$audio_stream" ]; then
    # No audio stream; adjust video speed only
    ffmpeg -loglevel warning -stats -i "$input_file" -filter:v "setpts=PTS/$speed_factor" -an "$output_file"
else
    # Audio stream present; adjust both video and audio speed
    ffmpeg -loglevel warning -stats -i "$input_file" -filter_complex "[0:v]setpts=PTS/$speed_factor[v];[0:a]$atempo_filters[a]" -map "[v]" -map "[a]" "$output_file"
fi

# Check if ffmpeg was successful
if [ $? -eq 0 ]; then
    echo "Success! Output saved to: $output_file"
else
    echo "Error: Video processing failed."
    exit 1
fi
