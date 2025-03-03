#!/bin/bash

# Function to display usage instructions
usage() {
    echo "Usage: $0 [options] <input_file>"
    echo ""
    echo "Options:"
    echo "  -o, --output FILE        Specify output filename (default: inputfile_prepared.ext)"
    echo "  -f, --fps NUMBER         Target frame rate (default: 60)"
    echo "  -d, --duration SECONDS   Target duration in seconds (default: 59)"
    echo "  -n, --dry-run            Show what would happen without processing"
    echo "  -s, --single-pass        Use single pass processing (may be less efficient)"
    echo "  -h, --help               Show this help message"
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

# Format seconds to MM:SS
format_duration() {
    local seconds="$1"
    printf "%02d:%02d" $((seconds/60)) $((seconds%60))
}

# Initialize variables
output_file=""
target_fps=60
target_duration=59  # Just under 1 minute
dry_run=0
single_pass=0

# Process options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        -f|--fps)
            target_fps="$2"
            shift 2
            ;;
        -d|--duration)
            target_duration="$2"
            shift 2
            ;;
        -n|--dry-run)
            dry_run=1
            shift
            ;;
        -s|--single-pass)
            single_pass=1
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

# Check if input file is provided
if [ $# -ne 1 ]; then
    usage
fi

input_file="$1"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found."
    exit 1
fi

# Generate default output file name if not specified
if [ -z "$output_file" ]; then
    output_file="${input_file%.*}_prepared.${input_file##*.}"
fi

# Get the original video information
echo "Analyzing video: $input_file"
original_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$input_file" | bc -l)
original_duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration -of csv=p=0 "$input_file")
original_duration=${original_duration%.*}  # Remove fractional part

# Check if we got valid values
if [ -z "$original_fps" ] || [ -z "$original_duration" ]; then
    echo "Error: Could not determine video properties. Is this a valid video file?"
    exit 1
fi

# Calculate speed factor if needed
needs_fps_reduction=0
needs_duration_reduction=0
temp_file=""

# Check if we need to reduce frame rate
if (( $(echo "$original_fps > $target_fps" | bc -l) )); then
    needs_fps_reduction=1
    echo "Current frame rate: ${original_fps} fps (needs reduction to $target_fps fps)"
else
    echo "Current frame rate: ${original_fps} fps (already below target of $target_fps fps)"
fi

# Check if we need to reduce duration
if (( $(echo "$original_duration > $target_duration" | bc -l) )); then
    needs_duration_reduction=1
    speed_factor=$(echo "scale=6; $original_duration / $target_duration" | bc)
    echo "Current duration: $(format_duration $original_duration) (needs reduction to $(format_duration $target_duration))"
    echo "Speed factor needed: ${speed_factor}x"
else
    echo "Current duration: $(format_duration $original_duration) (already below target of $(format_duration $target_duration))"
fi

# Check if any processing is needed
if [ $needs_fps_reduction -eq 0 ] && [ $needs_duration_reduction -eq 0 ]; then
    echo "Video already meets requirements. No processing needed."
    if [ $dry_run -eq 0 ] && [ "$input_file" != "$output_file" ]; then
        echo "Copying file to output location..."
        cp "$input_file" "$output_file"
        echo "Done. Output saved to: $output_file"
    fi
    exit 0
fi

# If it's a dry run, exit here
if [ $dry_run -eq 1 ]; then
    echo "[DRY RUN] Would process video and save to: $output_file"
    exit 0
fi

echo "Processing video..."

# Determine the appropriate atempo filter values for audio if speeding up
if [ $needs_duration_reduction -eq 1 ]; then
    atempo_filters=""
    remaining_speed=$speed_factor
    while (( $(echo "$remaining_speed > 2.0" | bc -l) )); do
        atempo_filters+="atempo=2.0,"
        remaining_speed=$(echo "scale=6; $remaining_speed / 2.0" | bc)
    done
    atempo_filters+="atempo=$remaining_speed"
fi

# Check if the input file has an audio stream
audio_stream=$(ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 "$input_file")

# Process video based on what needs to be done
if [ $single_pass -eq 1 ] || ([ $needs_fps_reduction -eq 1 ] && [ $needs_duration_reduction -eq 1 ]); then
    # Do everything in a single pass
    echo "Using single pass processing..."
    
    # Prepare video filters
    video_filters="fps=$target_fps"
    if [ $needs_duration_reduction -eq 1 ]; then
        video_filters+=",setpts=PTS/$speed_factor"
    fi
    
    if [ -z "$audio_stream" ]; then
        # No audio stream
        ffmpeg -loglevel warning -stats -i "$input_file" -filter:v "$video_filters" -an "$output_file"
    else
        # With audio stream
        if [ $needs_duration_reduction -eq 1 ]; then
            # Need to adjust audio speed too
            ffmpeg -loglevel warning -stats -i "$input_file" \
                -filter_complex "[0:v]$video_filters[v];[0:a]$atempo_filters[a]" \
                -map "[v]" -map "[a]" "$output_file"
        else
            # Just pass audio through
            ffmpeg -loglevel warning -stats -i "$input_file" -filter:v "$video_filters" -c:a copy "$output_file"
        fi
    fi
else
    # Two-pass processing (if needed)
    if [ $needs_fps_reduction -eq 1 ]; then
        echo "Pass 1: Reducing frame rate..."
        temp_file="${output_file%.*}_temp.${output_file##*.}"
        
        if [ -z "$audio_stream" ]; then
            # No audio stream
            ffmpeg -loglevel warning -stats -i "$input_file" -filter:v "fps=$target_fps" -an "$temp_file"
        else
            # With audio stream
            ffmpeg -loglevel warning -stats -i "$input_file" -filter:v "fps=$target_fps" -c:a copy "$temp_file"
        fi
        
        input_file="$temp_file"
    fi
    
    if [ $needs_duration_reduction -eq 1 ]; then
        echo "Pass 2: Adjusting duration..."
        
        if [ -z "$audio_stream" ]; then
            # No audio stream; adjust video speed only
            ffmpeg -loglevel warning -stats -i "$input_file" -filter:v "setpts=PTS/$speed_factor" -an "$output_file"
        else
            # Audio stream present; adjust both video and audio speed
            ffmpeg -loglevel warning -stats -i "$input_file" \
                -filter_complex "[0:v]setpts=PTS/$speed_factor[v];[0:a]$atempo_filters[a]" \
                -map "[v]" -map "[a]" "$output_file"
        fi
    else
        # If we only did fps reduction and created a temp file, rename it
        if [ -n "$temp_file" ]; then
            mv "$temp_file" "$output_file"
        fi
    fi
    
    # Clean up temporary file if it exists and wasn't moved
    if [ -n "$temp_file" ] && [ -f "$temp_file" ]; then
        rm "$temp_file"
    fi
fi

# Check if ffmpeg was successful
if [ $? -eq 0 ]; then
    echo "Success! Video prepared and saved to: $output_file"
    
    # Display final video information
    final_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$output_file" | bc -l)
    final_duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration -of csv=p=0 "$output_file")
    final_duration=${final_duration%.*}
    
    echo "Final video properties:"
    echo "- Frame rate: ${final_fps} fps"
    echo "- Duration: $(format_duration $final_duration)"
else
    echo "Error: Video processing failed."
    # Clean up output file if it exists but processing failed
    if [ -f "$output_file" ]; then
        rm "$output_file"
    fi
    exit 1
fi
