#!/bin/bash

convert_to_bytes() {
    local size=$1
    echo $((size * 1024 * 1024))
}

get_file_size() {
    stat -f%z "$1" 2>/dev/null || stat -c%s "$1"
}

compress_video() {
    input_file=$1
    target_size_mb=$2
    
    input_extension=$(echo "${input_file##*.}" | tr '[:upper:]' '[:lower:]')
    if [ "$input_extension" = "mov" ] && [ "$3" = "mp4" ]; then
        output_file="${input_file%.*}_compressed.mp4"
    else
        output_file="${input_file%.*}_compressed.${input_file##*.}"
    fi
    
    duration=$(ffmpeg -i "$input_file" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed 's/,//')
    hours=$(echo "$duration" | cut -d':' -f1)
    minutes=$(echo "$duration" | cut -d':' -f2)
    seconds=$(echo "$duration" | cut -d':' -f3)
    duration_seconds=$(echo "$hours * 3600 + $minutes * 60 + $seconds" | bc)
    duration_seconds=$(echo "($duration_seconds + 0.5)/1" | bc)
    
    target_size_bytes=$(convert_to_bytes $target_size_mb)
    target_bitrate=$((target_size_bytes * 8 / duration_seconds))
    echo "Target bitrate: $target_bitrate bits/second"
    
    ffmpeg -i "$input_file" -b:v $target_bitrate -bufsize $target_bitrate \
        -maxrate $((target_bitrate * 2)) \
        -preset slow -c:a aac -b:a 128k \
        "$output_file"
        
    final_size=$(get_file_size "$output_file")
    echo "Original size: $(get_file_size "$input_file" | awk '{print $1/1024/1024 "MB"}')"
    echo "Final size: $(echo $final_size | awk '{print $1/1024/1024 "MB"}')"
}

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first."
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo "Error: bc is not installed. Please install it first."
    exit 1
fi

if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
    echo "Usage: $0 input_file target_size_mb [mp4]"
    echo "Example: $0 video.mov 95"
    echo "Example with MP4 conversion: $0 video.mov 95 mp4"
    exit 1
fi

compress_video "$1" "$2" "$3"